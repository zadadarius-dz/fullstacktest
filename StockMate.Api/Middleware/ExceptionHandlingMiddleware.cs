using Microsoft.AspNetCore.Mvc;
using Npgsql;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Middleware;

public sealed class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            // Client memutus koneksi; tidak perlu menulis response.
        }
        catch (Exception ex)
        {
            if (context.Response.HasStarted)
            {
                _logger.LogError(ex, "Exception setelah response dimulai. TraceId: {TraceId}", context.TraceIdentifier);
                throw;
            }

            await WriteProblemAsync(context, ex);
        }
    }

    private async Task WriteProblemAsync(HttpContext context, Exception exception)
    {
        var traceId = context.TraceIdentifier;
        var (status, title, detail) = Map(exception, traceId);

        if (status >= 500)
        {
            _logger.LogError(exception,
                "Unhandled exception. Method={Method} Path={Path} TraceId={TraceId}",
                context.Request.Method, context.Request.Path, traceId);
        }
        else
        {
            _logger.LogWarning(
                "Request ditolak. Status={Status} Method={Method} Path={Path} TraceId={TraceId} Reason={Reason}",
                status, context.Request.Method, context.Request.Path, traceId, title);
        }

        context.Response.Clear();
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/problem+json; charset=utf-8";

        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = detail,
            Instance = context.Request.Path
        };
        problem.Extensions["traceId"] = traceId;

        await context.Response.WriteAsJsonAsync(problem);
    }

    private static (int Status, string Title, string Detail) Map(Exception exception, string traceId)
    {
        if (exception is AppException appException)
        {
            return (appException.StatusCode, appException.Title, appException.Message);
        }

        if (exception is PostgresException postgresException)
        {
            return postgresException.SqlState switch
            {
                PostgresErrorCodes.UniqueViolation =>
                    (StatusCodes.Status409Conflict, "Konflik data", "Data dengan nilai unik tersebut sudah ada."),
                PostgresErrorCodes.ForeignKeyViolation =>
                    (StatusCodes.Status409Conflict, "Konflik data", "Operasi ditolak karena data masih direferensikan."),
                PostgresErrorCodes.CheckViolation =>
                    (StatusCodes.Status400BadRequest, "Permintaan tidak valid", "Data melanggar aturan validasi."),
                _ => (StatusCodes.Status500InternalServerError, "Terjadi kesalahan server",
                    $"Terjadi kesalahan internal. Sertakan kode {traceId} saat melapor.")
            };
        }

        if (exception is BadHttpRequestException)
        {
            return (StatusCodes.Status400BadRequest, "Permintaan tidak valid", "Format permintaan tidak dapat diproses.");
        }

        return (StatusCodes.Status500InternalServerError, "Terjadi kesalahan server",
            $"Terjadi kesalahan internal. Sertakan kode {traceId} saat melapor.");
    }
}
