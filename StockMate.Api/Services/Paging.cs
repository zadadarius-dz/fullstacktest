namespace StockMate.Api.Services;

public static class Paging
{
    public const int MaxPageSize = 100;

    public static (int Page, int PageSize) Normalize(int page, int pageSize, int defaultPageSize)
    {
        var safePage = page < 1 ? 1 : page;
        var safeSize = pageSize < 1 ? defaultPageSize : Math.Min(pageSize, MaxPageSize);
        return (safePage, safeSize);
    }

    public static int TotalPages(int totalItems, int pageSize)
        => pageSize <= 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);
}
