using Dapper;
using StockMate.Api.Data;
using StockMate.Api.Models;

namespace StockMate.Api.Repositories;

public interface ICategoryRepository
{
    Task<IReadOnlyList<Category>> GetAllAsync(Guid userId);
    Task<Category?> GetByIdAsync(Guid userId, Guid id);
    Task<bool> NameExistsAsync(Guid userId, string name, Guid? excludeId = null);
    Task<bool> HasProductsAsync(Guid userId, Guid categoryId);
    Task<Category> CreateAsync(Category category);
    Task<Category?> UpdateAsync(Category category);
    Task<bool> DeleteAsync(Guid userId, Guid id);
    Task<int> CountAsync(Guid userId);
}

public sealed class CategoryRepository : ICategoryRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public CategoryRepository(IDbConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<Category>> GetAllAsync(Guid userId)
    {
        await using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<Category>(
            """
            SELECT id, user_id, name, created_at, updated_at
            FROM categories
            WHERE user_id = @UserId
            ORDER BY lower(name) ASC
            """,
            new { UserId = userId });
        return rows.AsList();
    }

    public async Task<Category?> GetByIdAsync(Guid userId, Guid id)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Category>(
            """
            SELECT id, user_id, name, created_at, updated_at
            FROM categories
            WHERE id = @Id AND user_id = @UserId
            """,
            new { Id = id, UserId = userId });
    }

    public async Task<bool> NameExistsAsync(Guid userId, string name, Guid? excludeId = null)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<bool>(
            """
            SELECT EXISTS (
                SELECT 1 FROM categories
                WHERE user_id = @UserId
                  AND lower(btrim(name)) = lower(btrim(@Name))
                  AND (@ExcludeId IS NULL OR id <> @ExcludeId)
            )
            """,
            new { UserId = userId, Name = name, ExcludeId = excludeId });
    }

    public async Task<bool> HasProductsAsync(Guid userId, Guid categoryId)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<bool>(
            """
            SELECT EXISTS (
                SELECT 1 FROM products
                WHERE category_id = @CategoryId AND user_id = @UserId
            )
            """,
            new { CategoryId = categoryId, UserId = userId });
    }

    public async Task<Category> CreateAsync(Category category)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleAsync<Category>(
            """
            INSERT INTO categories (id, user_id, name)
            VALUES (@Id, @UserId, @Name)
            RETURNING id, user_id, name, created_at, updated_at
            """,
            category);
    }

    public async Task<Category?> UpdateAsync(Category category)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Category>(
            """
            UPDATE categories
            SET name = @Name
            WHERE id = @Id AND user_id = @UserId
            RETURNING id, user_id, name, created_at, updated_at
            """,
            category);
    }

    public async Task<bool> DeleteAsync(Guid userId, Guid id)
    {
        await using var connection = _connectionFactory.CreateConnection();
        var affected = await connection.ExecuteAsync(
            "DELETE FROM categories WHERE id = @Id AND user_id = @UserId",
            new { Id = id, UserId = userId });
        return affected > 0;
    }

    public async Task<int> CountAsync(Guid userId)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<int>(
            "SELECT count(*)::int FROM categories WHERE user_id = @UserId",
            new { UserId = userId });
    }
}
