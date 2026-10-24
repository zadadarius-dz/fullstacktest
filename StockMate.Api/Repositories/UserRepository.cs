using Dapper;
using StockMate.Api.Data;
using StockMate.Api.Models;

namespace StockMate.Api.Repositories;

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string normalizedEmail);
    Task<User?> GetByIdAsync(Guid id);
    Task<bool> EmailExistsAsync(string normalizedEmail);
    Task<User> CreateAsync(User user);
}

public sealed class UserRepository : IUserRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public UserRepository(IDbConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    public async Task<User?> GetByEmailAsync(string normalizedEmail)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<User>(
            """
            SELECT id, name, email, password_hash, created_at, updated_at
            FROM users
            WHERE lower(email) = @Email
            """,
            new { Email = normalizedEmail });
    }

    public async Task<User?> GetByIdAsync(Guid id)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<User>(
            """
            SELECT id, name, email, password_hash, created_at, updated_at
            FROM users
            WHERE id = @Id
            """,
            new { Id = id });
    }

    public async Task<bool> EmailExistsAsync(string normalizedEmail)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.ExecuteScalarAsync<bool>(
            "SELECT EXISTS (SELECT 1 FROM users WHERE lower(email) = @Email)",
            new { Email = normalizedEmail });
    }

    public async Task<User> CreateAsync(User user)
    {
        await using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleAsync<User>(
            """
            INSERT INTO users (id, name, email, password_hash)
            VALUES (@Id, @Name, @Email, @PasswordHash)
            RETURNING id, name, email, password_hash, created_at, updated_at
            """,
            user);
    }
}
