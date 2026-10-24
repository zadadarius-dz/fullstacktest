using Npgsql;

namespace StockMate.Api.Data;

public interface IDbConnectionFactory
{
    NpgsqlConnection CreateConnection();
}

public sealed class NpgsqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public NpgsqlConnectionFactory(IConfiguration configuration)
    {
        var raw = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(raw))
        {
            raw = Environment.GetEnvironmentVariable("DATABASE_URL");
        }

        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new InvalidOperationException(
                "Connection string PostgreSQL belum dikonfigurasi. Set 'ConnectionStrings__DefaultConnection' " +
                "atau 'DATABASE_URL' melalui environment variable. Lihat README untuk contoh.");
        }

        var normalised = raw.Trim().StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) ||
                         raw.Trim().StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase)
            ? ConvertDatabaseUrl(raw.Trim())
            : raw;

        var builder = new NpgsqlConnectionStringBuilder(normalised)
        {
            ApplicationName = "StockMate.Api"
        };
        _connectionString = builder.ConnectionString;
    }

    public NpgsqlConnection CreateConnection() => new(_connectionString);

    /// <summary>Mendukung format DATABASE_URL (postgres://user:pass@host:port/db) yang umum di hosting.</summary>
    private static string ConvertDatabaseUrl(string databaseUrl)
    {
        var uri = new Uri(databaseUrl);
        var userInfo = uri.UserInfo.Split(':', 2);
        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.IsDefaultPort ? 5432 : uri.Port,
            Database = Uri.UnescapeDataString(uri.AbsolutePath.TrimStart('/')),
            Username = userInfo.Length > 0 ? Uri.UnescapeDataString(userInfo[0]) : string.Empty,
            Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty
        };

        if (!string.IsNullOrEmpty(uri.Query))
        {
            // Teruskan opsi seperti sslmode bila ada.
            foreach (var pair in uri.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
            {
                var parts = pair.Split('=', 2);
                if (parts.Length == 2 && parts[0].Equals("sslmode", StringComparison.OrdinalIgnoreCase))
                {
                    builder.SslMode = Enum.Parse<SslMode>(parts[1], ignoreCase: true);
                }
            }
        }

        return builder.ConnectionString;
    }
}
