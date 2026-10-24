using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace StockMate.Api.Tests;

/// <summary>
/// Factory integration test. Database diambil dari environment variable
/// STOCKMATE_TEST_DATABASE agar tidak ada credential di source control.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public const string TestSigningKey = "stockmate-integration-test-signing-key-0123456789";

    private readonly string _connectionString;

    public ApiFactory(string connectionString)
    {
        _connectionString = connectionString;

        // Program membaca configuration saat host dibuat. Environment variable
        // adalah cara paling andal untuk override sebelum WebApplicationFactory
        // menjalankan top-level Program.
        Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Development");
        Environment.SetEnvironmentVariable("ConnectionStrings__DefaultConnection", _connectionString);
        Environment.SetEnvironmentVariable("Jwt__SigningKey", TestSigningKey);
        Environment.SetEnvironmentVariable("Jwt__Issuer", "StockMate.Api");
        Environment.SetEnvironmentVariable("Jwt__Audience", "StockMate.Clients");
        Environment.SetEnvironmentVariable("Database__AutoMigrate", "true");
        Environment.SetEnvironmentVariable("Swagger__Enabled", "false");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
    }
}
