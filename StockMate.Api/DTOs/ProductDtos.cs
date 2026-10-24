using System.ComponentModel.DataAnnotations;

namespace StockMate.Api.DTOs;

public sealed class CreateProductRequest
{
    [Required(ErrorMessage = "SKU wajib diisi.")]
    [StringLength(64, MinimumLength = 1, ErrorMessage = "SKU maksimal 64 karakter.")]
    public string Sku { get; set; } = string.Empty;

    [Required(ErrorMessage = "Nama produk wajib diisi.")]
    [StringLength(160, MinimumLength = 2, ErrorMessage = "Nama produk harus 2-160 karakter.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Kategori wajib dipilih.")]
    public Guid CategoryId { get; set; }

    [StringLength(500, ErrorMessage = "Deskripsi maksimal 500 karakter.")]
    public string? Description { get; set; }

    [Range(0, 999999999999.99, ErrorMessage = "Harga tidak boleh negatif.")]
    public decimal Price { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Stok minimum tidak boleh negatif.")]
    public int MinStock { get; set; }
}

public sealed class UpdateProductRequest
{
    [Required(ErrorMessage = "SKU wajib diisi.")]
    [StringLength(64, MinimumLength = 1, ErrorMessage = "SKU maksimal 64 karakter.")]
    public string Sku { get; set; } = string.Empty;

    [Required(ErrorMessage = "Nama produk wajib diisi.")]
    [StringLength(160, MinimumLength = 2, ErrorMessage = "Nama produk harus 2-160 karakter.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Kategori wajib dipilih.")]
    public Guid CategoryId { get; set; }

    [StringLength(500, ErrorMessage = "Deskripsi maksimal 500 karakter.")]
    public string? Description { get; set; }

    [Range(0, 999999999999.99, ErrorMessage = "Harga tidak boleh negatif.")]
    public decimal Price { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Stok minimum tidak boleh negatif.")]
    public int MinStock { get; set; }

    /// <summary>Bila null, status aktif produk tidak diubah.</summary>
    public bool? IsActive { get; set; }
}

public sealed class ProductResponse
{
    public Guid Id { get; init; }
    public string Sku { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public Guid CategoryId { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public string? Description { get; init; }
    public decimal Price { get; init; }
    public int StockQuantity { get; init; }
    public int MinStock { get; init; }
    public bool IsActive { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}

public sealed class ProductQuery
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
    public string? Search { get; set; }
    public Guid? CategoryId { get; set; }
    public bool LowStock { get; set; }
}
