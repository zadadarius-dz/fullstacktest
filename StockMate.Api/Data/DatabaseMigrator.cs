namespace StockMate.Api.Data;

public sealed class DatabaseMigrator
{
    private readonly IDbConnectionFactory _connectionFactory;
    private readonly IHostEnvironment _environment;
    private readonly ILogger<DatabaseMigrator> _logger;

    public DatabaseMigrator(
        IDbConnectionFactory connectionFactory,
        IHostEnvironment environment,
        ILogger<DatabaseMigrator> logger)
    {
        _connectionFactory = connectionFactory;
        _environment = environment;
        _logger = logger;
    }

    public async Task ApplyAsync(CancellationToken cancellationToken = default)
    {
        var path = Path.Combine(_environment.ContentRootPath, "Data", "Migrations", "001_initial_schema.sql");
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("File migration tidak ditemukan.", path);
        }

        var sql = await File.ReadAllTextAsync(path, cancellationToken);

        await using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync(cancellationToken);

        _logger.LogInformation("Migration database berhasil diterapkan.");
    }
}
