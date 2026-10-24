using System.Text;
using Dapper;
using StockMate.Api.Data;
using StockMate.Api.DTOs;
using StockMate.Api.Models;

namespace StockMate.Api.Repositories;

public sealed class ProductStats
{
    public int ActiveProducts { get; set; }
    public long TotalStockUnits { get; set; }
    public int LowStockProducts { get; set; }
}

public interface IProductRepository
{
    Task<(IReadOnlyList<Product> Items, int TotalItems)> GetPagedAsync(Guid userId, ProductQuery query);
    Task<Product?> GetByIdAsync(Guid userId, Guid id, bool includeInactive = false);
    Task<bool> SkuExistsAsync(Guid userId, string sku, Guid? excludeId = null);
    Task<Product> CreateAsync(Product product);
    Task<Product?> UpdateAsync(Product product);
    Task<bool> SoftDeleteAsync(Guid userId, Guid id);
    Task<ProductStats> GetStatsAsync(Guid userId);
    Task<IReadOnlyList<Product>> GetLowStockAsync(Guid userId, int limit);
}

public sealed class ProductRepository : IProductRepository
{
    private const string ProductSelectColumns =
        """
        p.id, p.user_id, p.category_id, p.sku, p.name, p.description, p.price,
        p.stock_quantity, p.min_stock, p.is_active, p.created_at, p.updated_at,
        c.name AS category_name
        """;

    private readonly IDbConnectionFactory _connectionFactory;

    public ProductRepository(IDbConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    public async Task<(IReadOnlyList<Product> Items, int TotalItems)> GetPagedAsync(Guid userId, ProductQuery query)
    {
        var where = new StringBuilder("p.user_id = @UserId AND p.is_active = TRUE");

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            where.Append(" AND (p.name ILIKE @Search ESCAPE '\\' OR p.sku ILIKE @Search ESCAPE '\\')");
        }

        if (query.CategoryId.HasValue)
        {
            where.Append(" AND p.category_id = @CategoryId");
        }

        if (query.LowStock)
        {
            where.Append(" AND p.stock_quantity <= p.min_stock");
        }

        var parameters = new
        {
            UserId = userId,
            Search = string.IsNullOrWhiteSpace(query.Search) ? null : $"%{EscapeLike(query.Search.Trim())}%",
            query.CategoryId,
            Limit = query.PageSize,
            Offset = (query.Page - 1) * query.PageSize
        };

        await using var connection = _connectionFactory.CreateConnection();

        var total = await connection.ExecuteScalarAsync<int>(
            $"SELECT count(*)::int FROM products p WHERE {where}",
            parameters);

        var items = await connection.QueryAsync<Product>(
            $"""
             SELECT {ProductSelectColumns}
             FROM products p
             JOIN categories c ON c.id = p.category_id
             WHERE {where}
             ORDER BY p.created_at DESC, p.id DESC
             LIMIT @Limit OFFSET @Offset
             """,
            parameters);

        return (items.AsList(), total);
    }

    public async Task<Product?> GetByIdAsync(Guid userId, Guid id, bool includeInactive = false)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Product>(
            $"""
             SELECT {ProductSelectColumns}
             FROM products p
             JOIN categories c ON c.id = p.category_id
             WHERE p.id = @Id AND p.user_id = @UserId AND (p.is_active = TRUE OR @IncludeInactive = TRUE)
             """,
            new { Id = id, UserId = userId, IncludeInactive = includeInactive });
    }

    public async Task<bool> SkuExistsAsync(Guid userId, string sku, Guid? excludeId = null)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<bool>(
            """
            SELECT EXISTS (
                SELECT 1 FROM products
                WHERE user_id = @UserId
                  AND sku = @Sku
                  AND (@ExcludeId IS NULL OR id <> @ExcludeId)
            )
            """,
            new { UserId = userId, Sku = sku, ExcludeId = excludeId });
    }

    public async Task<Product> CreateAsync(Product product)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleAsync<Product>(
            """
            WITH inserted AS (
                INSERT INTO products
                    (id, user_id, category_id, sku, name, description, price, stock_quantity, min_stock, is_active)
                VALUES
                    (@Id, @UserId, @CategoryId, @Sku, @Name, @Description, @Price, 0, @MinStock, TRUE)
                RETURNING id, user_id, category_id, sku, name, description, price,
                          stock_quantity, min_stock, is_active, created_at, updated_at
            )
            SELECT i.id, i.user_id, i.category_id, i.sku, i.name, i.description, i.price,
                   i.stock_quantity, i.min_stock, i.is_active, i.created_at, i.updated_at,
                   c.name AS category_name
            FROM inserted i
            JOIN categories c ON c.id = i.category_id
            """,
            product);
    }

    public async Task<Product?> UpdateAsync(Product product)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Product>(
            """
            WITH updated AS (
                UPDATE products
                SET category_id = @CategoryId,
                    sku = @Sku,
                    name = @Name,
                    description = @Description,
                    price = @Price,
                    min_stock = @MinStock,
                    is_active = @IsActive
                WHERE id = @Id AND user_id = @UserId AND is_active = TRUE
                RETURNING id, user_id, category_id, sku, name, description, price,
                          stock_quantity, min_stock, is_active, created_at, updated_at
            )
            SELECT u.id, u.user_id, u.category_id, u.sku, u.name, u.description, u.price,
                   u.stock_quantity, u.min_stock, u.is_active, u.created_at, u.updated_at,
                   c.name AS category_name
            FROM updated u
            JOIN categories c ON c.id = u.category_id
            """,
            product);
    }

    public async Task<bool> SoftDeleteAsync(Guid userId, Guid id)
    {
        await using var connection = _connectionFactory.CreateConnection();
        var affected = await connection.ExecuteAsync(
            """
            UPDATE products
            SET is_active = FALSE
            WHERE id = @Id AND user_id = @UserId AND is_active = TRUE
            """,
            new { Id = id, UserId = userId });
        return affected > 0;
    }

    public async Task<ProductStats> GetStatsAsync(Guid userId)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleAsync<ProductStats>(
            """
            SELECT
                count(*) FILTER (WHERE is_active)::int AS active_products,
                COALESCE(sum(stock_quantity) FILTER (WHERE is_active), 0)::bigint AS total_stock_units,
                count(*) FILTER (WHERE is_active AND stock_quantity <= min_stock)::int AS low_stock_products
            FROM products
            WHERE user_id = @UserId
            """,
            new { UserId = userId });
    }

    public async Task<IReadOnlyList<Product>> GetLowStockAsync(Guid userId, int limit)
    {
        await using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<Product>(
            """
            SELECT id, user_id, category_id, sku, name, stock_quantity, min_stock, is_active
            FROM products
            WHERE user_id = @UserId AND is_active = TRUE AND stock_quantity <= min_stock
            ORDER BY stock_quantity ASC, lower(name) ASC
            LIMIT @Limit
            """,
            new { UserId = userId, Limit = limit });
        return rows.AsList();
    }

    private static string EscapeLike(string value)
        => value.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
}
