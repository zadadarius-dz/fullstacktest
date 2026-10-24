using System.Net;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;

namespace StockMate.Api.Data;

public sealed class DatabaseHealthCheck : IHealthCheck
{
    private readonly IDbConnectionFactory _connectionFactory;

    public DatabaseHealthCheck(IDbConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = _connectionFactory.CreateConnection();
            await connection.OpenAsync(cancellationToken);
            await using var command = new NpgsqlCommand("SELECT 1", connection);
            var result = await command.ExecuteScalarAsync(cancellationToken);
            return result is 1
                ? HealthCheckResult.Healthy("Database dapat diakses.")
                : HealthCheckResult.Unhealthy("Database mengembalikan hasil tak terduga.");
        }
        catch (Exception ex)
        {
            // Jangan sertakan connection string/credential pada pesan health check.
            return HealthCheckResult.Unhealthy(
                $"Database tidak dapat diakses ({ex.GetType().Name}).",
                ex);
        }
    }
}

public static class HealthCheckResponseWriter
{
    public static Task WriteAsync(HttpContext context, HealthReport report)
    {
        context.Response.ContentType = "application/json; charset=utf-8";
        context.Response.StatusCode = report.Status == HealthStatus.Healthy
            ? (int)HttpStatusCode.OK
            : (int)HttpStatusCode.ServiceUnavailable;

        var payload = new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(entry => new
            {
                name = entry.Key,
                status = entry.Value.Status.ToString(),
                description = entry.Value.Description
            }),
            totalDurationMs = Math.Round(report.TotalDuration.TotalMilliseconds, 1)
        };

        return context.Response.WriteAsJsonAsync(payload);
    }
}
