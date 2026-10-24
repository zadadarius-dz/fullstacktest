namespace StockMate.Api.DTOs;

public sealed class LowStockItem
{
    public Guid Id { get; init; }
    public string Sku { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public int StockQuantity { get; init; }
    public int MinStock { get; init; }
}

public sealed class DashboardSummaryResponse
{
    public int ActiveProducts { get; init; }
    public int Categories { get; init; }
    public long TotalStockUnits { get; init; }
    public int LowStockProducts { get; init; }
    public IReadOnlyList<LowStockItem> LowStockItems { get; init; } = Array.Empty<LowStockItem>();
}
