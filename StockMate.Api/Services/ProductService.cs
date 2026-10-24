using StockMate.Api.DTOs;
using StockMate.Api.Models;
using StockMate.Api.Repositories;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Services;

public interface IProductService
{
    Task<PagedResponse<ProductResponse>> GetPagedAsync(ProductQuery query);
    Task<ProductResponse> GetByIdAsync(Guid id);
    Task<ProductResponse> CreateAsync(CreateProductRequest request);
    Task<ProductResponse> UpdateAsync(Guid id, UpdateProductRequest request);
    Task DeleteAsync(Guid id);
}

public sealed class ProductService : IProductService
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ICurrentUserService _currentUser;

    public ProductService(
        IProductRepository productRepository,
        ICategoryRepository categoryRepository,
        ICurrentUserService currentUser)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;
        _currentUser = currentUser;
    }

    public async Task<PagedResponse<ProductResponse>> GetPagedAsync(ProductQuery query)
    {
        var (page, pageSize) = Paging.Normalize(query.Page, query.PageSize, defaultPageSize: 10);
        var search = (query.Search ?? string.Empty).Trim();
        if (search.Length > 100)
        {
            throw new BadRequestException("Parameter pencarian maksimal 100 karakter.");
        }

        var normalized = new ProductQuery
        {
            Page = page,
            PageSize = pageSize,
            Search = search.Length == 0 ? null : search,
            CategoryId = query.CategoryId,
            LowStock = query.LowStock
        };

        var (items, totalItems) = await _productRepository.GetPagedAsync(_currentUser.UserId, normalized);

        return new PagedResponse<ProductResponse>
        {
            Items = items.Select(p => p.ToResponse()).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            TotalPages = Paging.TotalPages(totalItems, pageSize)
        };
    }

    public async Task<ProductResponse> GetByIdAsync(Guid id)
    {
        var product = await _productRepository.GetByIdAsync(_currentUser.UserId, id);
        return product?.ToResponse() ?? throw new NotFoundException("Produk tidak ditemukan.");
    }

    public async Task<ProductResponse> CreateAsync(CreateProductRequest request)
    {
        var userId = _currentUser.UserId;
        var sku = NormalizeSku(request.Sku);
        var name = NormalizeName(request.Name);
        var description = NormalizeDescription(request.Description);

        await EnsureCategoryOwnedAsync(userId, request.CategoryId);

        if (await _productRepository.SkuExistsAsync(userId, sku))
        {
            throw new ConflictException("SKU sudah digunakan.");
        }

        var product = new Product
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CategoryId = request.CategoryId,
            Sku = sku,
            Name = name,
            Description = description,
            Price = request.Price,
            StockQuantity = 0,
            MinStock = request.MinStock,
            IsActive = true
        };

        var created = await _productRepository.CreateAsync(product);
        return created.ToResponse();
    }

    public async Task<ProductResponse> UpdateAsync(Guid id, UpdateProductRequest request)
    {
        var userId = _currentUser.UserId;
        var existing = await _productRepository.GetByIdAsync(userId, id)
                       ?? throw new NotFoundException("Produk tidak ditemukan.");

        var sku = NormalizeSku(request.Sku);
        var name = NormalizeName(request.Name);
        var description = NormalizeDescription(request.Description);

        await EnsureCategoryOwnedAsync(userId, request.CategoryId);

        if (await _productRepository.SkuExistsAsync(userId, sku, id))
        {
            throw new ConflictException("SKU sudah digunakan.");
        }

        existing.CategoryId = request.CategoryId;
        existing.Sku = sku;
        existing.Name = name;
        existing.Description = description;
        existing.Price = request.Price;
        existing.MinStock = request.MinStock;
        existing.IsActive = request.IsActive ?? existing.IsActive;

        var updated = await _productRepository.UpdateAsync(existing)
                      ?? throw new NotFoundException("Produk tidak ditemukan.");

        return updated.ToResponse();
    }

    public async Task DeleteAsync(Guid id)
    {
        if (!await _productRepository.SoftDeleteAsync(_currentUser.UserId, id))
        {
            throw new NotFoundException("Produk tidak ditemukan.");
        }
    }

    private async Task EnsureCategoryOwnedAsync(Guid userId, Guid categoryId)
    {
        if (categoryId == Guid.Empty)
        {
            throw new BadRequestException("Kategori wajib dipilih.");
        }

        if (await _categoryRepository.GetByIdAsync(userId, categoryId) is null)
        {
            throw new NotFoundException("Kategori tidak ditemukan.");
        }
    }

    private static string NormalizeSku(string? sku)
    {
        var normalized = (sku ?? string.Empty).Trim().ToUpperInvariant();
        if (normalized.Length is < 1 or > 64)
        {
            throw new BadRequestException("SKU harus 1-64 karakter.");
        }

        return normalized;
    }

    private static string NormalizeName(string? name)
    {
        var normalized = (name ?? string.Empty).Trim();
        if (normalized.Length is < 2 or > 160)
        {
            throw new BadRequestException("Nama produk harus 2-160 karakter.");
        }

        return normalized;
    }

    private static string? NormalizeDescription(string? description)
    {
        var normalized = (description ?? string.Empty).Trim();
        if (normalized.Length > 500)
        {
            throw new BadRequestException("Deskripsi maksimal 500 karakter.");
        }

        return normalized.Length == 0 ? null : normalized;
    }
}
