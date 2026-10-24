namespace StockMate.Api.Services.Exceptions;

public abstract class AppException : Exception
{
    public abstract int StatusCode { get; }
    public abstract string Title { get; }

    protected AppException(string message) : base(message)
    {
    }
}

public sealed class NotFoundException : AppException
{
    public NotFoundException(string message) : base(message)
    {
    }

    public override int StatusCode => StatusCodes.Status404NotFound;
    public override string Title => "Resource tidak ditemukan";
}

public sealed class ConflictException : AppException
{
    public ConflictException(string message) : base(message)
    {
    }

    public override int StatusCode => StatusCodes.Status409Conflict;
    public override string Title => "Konflik data";
}

public sealed class UnauthorizedException : AppException
{
    public UnauthorizedException(string message) : base(message)
    {
    }

    public override int StatusCode => StatusCodes.Status401Unauthorized;
    public override string Title => "Tidak terautentikasi";
}

public sealed class BadRequestException : AppException
{
    public BadRequestException(string message) : base(message)
    {
    }

    public override int StatusCode => StatusCodes.Status400BadRequest;
    public override string Title => "Permintaan tidak valid";
}
