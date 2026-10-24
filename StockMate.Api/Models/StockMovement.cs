namespace StockMate.Api.Models;

public sealed class StockMovement
{
    public Guid Id { get; set; }
    public Guid ProductId { get; set; }
    public Guid CreatedByUserId { get; set; }
    public string Type { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public int StockBefore { get; set; }
    public int StockAfter { get; set; }
    public string? Note { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string ProductSku { get; set; } = string.Empty;
}
