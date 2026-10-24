using StockMate.Api.DTOs;
using StockMate.Api.Models;
using StockMate.Api.Repositories;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Services;

public interface ICategoryService
{
    Task<IReadOnlyList<CategoryResponse>> GetAllAsync();
    Task<CategoryResponse> GetByIdAsync(Guid id);
    Task<CategoryResponse> CreateAsync(CategoryRequest request);
    Task<CategoryResponse> UpdateAsync(Guid id, CategoryRequest request);
    Task DeleteAsync(Guid id);
}

public sealed class CategoryService : ICategoryService
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly ICurrentUserService _currentUser;

    public CategoryService(ICategoryRepository categoryRepository, ICurrentUserService currentUser)
    {
        _categoryRepository = categoryRepository;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<CategoryResponse>> GetAllAsync()
    {
        var categories = await _categoryRepository.GetAllAsync(_currentUser.UserId);
        return categories.Select(c => c.ToResponse()).ToList();
    }

    public async Task<CategoryResponse> GetByIdAsync(Guid id)
    {
        var category = await _categoryRepository.GetByIdAsync(_currentUser.UserId, id);
        return category?.ToResponse() ?? throw new NotFoundException("Kategori tidak ditemukan.");
    }

    public async Task<CategoryResponse> CreateAsync(CategoryRequest request)
    {
        var userId = _currentUser.UserId;
        var name = NormalizeName(request.Name);

        if (await _categoryRepository.NameExistsAsync(userId, name))
        {
            throw new ConflictException("Nama kategori sudah digunakan.");
        }

        var category = new Category
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = name
        };

        var created = await _categoryRepository.CreateAsync(category);
        return created.ToResponse();
    }

    public async Task<CategoryResponse> UpdateAsync(Guid id, CategoryRequest request)
    {
        var userId = _currentUser.UserId;
        var existing = await _categoryRepository.GetByIdAsync(userId, id)
                       ?? throw new NotFoundException("Kategori tidak ditemukan.");

        var name = NormalizeName(request.Name);

        if (await _categoryRepository.NameExistsAsync(userId, name, id))
        {
            throw new ConflictException("Nama kategori sudah digunakan.");
        }

        existing.Name = name;
        var updated = await _categoryRepository.UpdateAsync(existing)
                      ?? throw new NotFoundException("Kategori tidak ditemukan.");

        return updated.ToResponse();
    }

    public async Task DeleteAsync(Guid id)
    {
        var userId = _currentUser.UserId;

        if (await _categoryRepository.GetByIdAsync(userId, id) is null)
        {
            throw new NotFoundException("Kategori tidak ditemukan.");
        }

        if (await _categoryRepository.HasProductsAsync(userId, id))
        {
            throw new ConflictException("Kategori tidak dapat dihapus karena masih digunakan oleh produk.");
        }

        if (!await _categoryRepository.DeleteAsync(userId, id))
        {
            throw new NotFoundException("Kategori tidak ditemukan.");
        }
    }

    private static string NormalizeName(string? name)
    {
        var trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length < 2 || trimmed.Length > 80)
        {
            throw new BadRequestException("Nama kategori harus 2-80 karakter.");
        }

        return trimmed;
    }
}
