using Dapper;
using StockMate.Api.Data;
using StockMate.Api.Models;

namespace StockMate.Api.Repositories;

public sealed class RecordMovementResult
{
    public StockMovement? Movement { get; init; }
    public string? Failure { get; init; }
    public int AvailableStock { get; init; }
}

public interface IStockMovementRepository
{
    Task<RecordMovementResult> RecordAsync(
        Guid userId, Guid productId, string type, int quantity, string? note);

    Task<(IReadOnlyList<StockMovement> Items, int TotalItems)> GetByProductPagedAsync(
        Guid userId, Guid productId, int page, int pageSize);

    Task<(IReadOnlyList<StockMovement> Items, int TotalItems)> GetPagedAsync(
        Guid userId, int page, int pageSize);
}

public sealed class StockMovementRepository : IStockMovementRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public StockMovementRepository(IDbConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    public async Task<RecordMovementResult> RecordAsync(
        Guid userId, Guid productId, string type, int quantity, string? note)
    {
        await using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        // Row lock mencegah dua request mengubah stok yang sama secara bersamaan.
        var product = await connection.QuerySingleOrDefaultAsync<Product>(
            """
            SELECT id, user_id, sku, name, stock_quantity, min_stock, is_active
            FROM products
            WHERE id = @ProductId AND user_id = @UserId AND is_active = TRUE
            FOR UPDATE
            """,
            new { ProductId = productId, UserId = userId },
            transaction);

        if (product is null)
        {
            await transaction.RollbackAsync();
            return new RecordMovementResult { Failure = "PRODUCT_NOT_FOUND" };
        }

        var stockBefore = product.StockQuantity;
        var stockAfterLong = type == "IN"
            ? (long)stockBefore + quantity
            : (long)stockBefore - quantity;

        if (stockAfterLong < 0)
        {
            await transaction.RollbackAsync();
            return new RecordMovementResult
            {
                Failure = "INSUFFICIENT_STOCK",
                AvailableStock = stockBefore
            };
        }

        if (stockAfterLong > int.MaxValue)
        {
            await transaction.RollbackAsync();
            return new RecordMovementResult
            {
                Failure = "STOCK_OVERFLOW",
                AvailableStock = stockBefore
            };
        }

        var stockAfter = (int)stockAfterLong;

        var updated = await connection.ExecuteAsync(
            """
            UPDATE products
            SET stock_quantity = @StockAfter
            WHERE id = @ProductId AND user_id = @UserId
            """,
            new { StockAfter = stockAfter, ProductId = productId, UserId = userId },
            transaction);

        if (updated != 1)
        {
            await transaction.RollbackAsync();
            return new RecordMovementResult { Failure = "PRODUCT_NOT_FOUND" };
        }

        var movement = await connection.QuerySingleAsync<StockMovement>(
            """
            INSERT INTO stock_movements
                (id, product_id, created_by_user_id, type, quantity, stock_before, stock_after, note)
            VALUES
                (@Id, @ProductId, @CreatedByUserId, @Type, @Quantity, @StockBefore, @StockAfter, @Note)
            RETURNING id, product_id, created_by_user_id, type, quantity,
                      stock_before, stock_after, note, created_at
            """,
            new
            {
                Id = Guid.NewGuid(),
                ProductId = productId,
                CreatedByUserId = userId,
                Type = type,
                Quantity = quantity,
                StockBefore = stockBefore,
                StockAfter = stockAfter,
                Note = note
            },
            transaction);

        await transaction.CommitAsync();

        movement.ProductName = product.Name;
        movement.ProductSku = product.Sku;
        return new RecordMovementResult { Movement = movement };
    }

    public async Task<(IReadOnlyList<StockMovement> Items, int TotalItems)> GetByProductPagedAsync(
        Guid userId, Guid productId, int page, int pageSize)
    {
        await using var connection = _connectionFactory.CreateConnection();

        var total = await connection.ExecuteScalarAsync<int>(
            """
            SELECT count(*)::int
            FROM stock_movements m
            WHERE m.product_id = @ProductId AND m.created_by_user_id = @UserId
            """,
            new { ProductId = productId, UserId = userId });

        var items = await connection.QueryAsync<StockMovement>(
            """
            SELECT m.id, m.product_id, m.created_by_user_id, m.type, m.quantity,
                   m.stock_before, m.stock_after, m.note, m.created_at,
                   p.name AS product_name, p.sku AS product_sku
            FROM stock_movements m
            JOIN products p ON p.id = m.product_id
            WHERE m.product_id = @ProductId AND m.created_by_user_id = @UserId
            ORDER BY m.created_at DESC, m.id DESC
            LIMIT @Limit OFFSET @Offset
            """,
            new
            {
                ProductId = productId,
                UserId = userId,
                Limit = pageSize,
                Offset = (page - 1) * pageSize
            });

        return (items.AsList(), total);
    }

    public async Task<(IReadOnlyList<StockMovement> Items, int TotalItems)> GetPagedAsync(
        Guid userId, int page, int pageSize)
    {
        await using var connection = _connectionFactory.CreateConnection();

        var total = await connection.ExecuteScalarAsync<int>(
            "SELECT count(*)::int FROM stock_movements WHERE created_by_user_id = @UserId",
            new { UserId = userId });

        var items = await connection.QueryAsync<StockMovement>(
            """
            SELECT m.id, m.product_id, m.created_by_user_id, m.type, m.quantity,
                   m.stock_before, m.stock_after, m.note, m.created_at,
                   p.name AS product_name, p.sku AS product_sku
            FROM stock_movements m
            JOIN products p ON p.id = m.product_id
            WHERE m.created_by_user_id = @UserId
            ORDER BY m.created_at DESC, m.id DESC
            LIMIT @Limit OFFSET @Offset
            """,
            new
            {
                UserId = userId,
                Limit = pageSize,
                Offset = (page - 1) * pageSize
            });

        return (items.AsList(), total);
    }
}
