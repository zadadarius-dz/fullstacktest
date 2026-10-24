using System.ComponentModel.DataAnnotations;

namespace StockMate.Api.DTOs;

public sealed class CategoryRequest
{
    [Required(ErrorMessage = "Nama kategori wajib diisi.")]
    [StringLength(80, MinimumLength = 2, ErrorMessage = "Nama kategori harus 2-80 karakter.")]
    public string Name { get; set; } = string.Empty;
}

public sealed class CategoryResponse
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}
