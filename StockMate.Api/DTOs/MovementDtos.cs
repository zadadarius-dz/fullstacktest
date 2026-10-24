using System.ComponentModel.DataAnnotations;

namespace StockMate.Api.DTOs;

public sealed class CreateMovementRequest
{
    [Required(ErrorMessage = "Tipe pergerakan wajib diisi.")]
    [RegularExpression("^(IN|OUT)$", ErrorMessage = "Tipe harus IN atau OUT.")]
    public string Type { get; set; } = string.Empty;

    [Range(1, int.MaxValue, ErrorMessage = "Quantity harus bilangan bulat positif.")]
    public int Quantity { get; set; }

    [StringLength(300, ErrorMessage = "Catatan maksimal 300 karakter.")]
    public string? Note { get; set; }
}

public sealed class MovementResponse
{
    public Guid Id { get; init; }
    public Guid ProductId { get; init; }
    public string ProductSku { get; init; } = string.Empty;
    public string ProductName { get; init; } = string.Empty;
    public string Type { get; init; } = string.Empty;
    public int Quantity { get; init; }
    public int StockBefore { get; init; }
    public int StockAfter { get; init; }
    public string? Note { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
}
