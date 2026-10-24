using StockMate.Api.DTOs;
using StockMate.Api.Repositories;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Services;

public interface IStockMovementService
{
    Task<MovementResponse> CreateAsync(Guid productId, CreateMovementRequest request);
    Task<PagedResponse<MovementResponse>> GetByProductAsync(Guid productId, int page, int pageSize);
    Task<PagedResponse<MovementResponse>> GetAllAsync(int page, int pageSize);
}

public sealed class StockMovementService : IStockMovementService
{
    private readonly IStockMovementRepository _movementRepository;
    private readonly IProductRepository _productRepository;
    private readonly ICurrentUserService _currentUser;

    public StockMovementService(
        IStockMovementRepository movementRepository,
        IProductRepository productRepository,
        ICurrentUserService currentUser)
    {
        _movementRepository = movementRepository;
        _productRepository = productRepository;
        _currentUser = currentUser;
    }

    public async Task<MovementResponse> CreateAsync(Guid productId, CreateMovementRequest request)
    {
        var type = (request.Type ?? string.Empty).Trim().ToUpperInvariant();
        if (type is not ("IN" or "OUT"))
        {
            throw new BadRequestException("Tipe pergerakan harus IN atau OUT.");
        }

        if (request.Quantity <= 0)
        {
            throw new BadRequestException("Quantity harus bilangan bulat positif.");
        }

        var note = (request.Note ?? string.Empty).Trim();
        if (note.Length > 300)
        {
            throw new BadRequestException("Catatan maksimal 300 karakter.");
        }

        var result = await _movementRepository.RecordAsync(
            _currentUser.UserId,
            productId,
            type,
            request.Quantity,
            note.Length == 0 ? null : note);

        if (result.Failure == "PRODUCT_NOT_FOUND")
        {
            throw new NotFoundException("Produk aktif tidak ditemukan.");
        }

        if (result.Failure == "INSUFFICIENT_STOCK")
        {
            throw new ConflictException($"Stok tidak mencukupi. Stok tersedia: {result.AvailableStock}.");
        }

        if (result.Failure == "STOCK_OVERFLOW")
        {
            throw new ConflictException("Jumlah stok melebihi batas maksimum yang didukung.");
        }

        return result.Movement!.ToResponse();
    }

    public async Task<PagedResponse<MovementResponse>> GetByProductAsync(Guid productId, int page, int pageSize)
    {
        var userId = _currentUser.UserId;

        // Riwayat tetap dapat dibaca untuk produk yang sudah soft-deleted.
        if (await _productRepository.GetByIdAsync(userId, productId, includeInactive: true) is null)
        {
            throw new NotFoundException("Produk tidak ditemukan.");
        }

        var (safePage, safeSize) = Paging.Normalize(page, pageSize, defaultPageSize: 20);
        var (items, totalItems) = await _movementRepository.GetByProductPagedAsync(
            userId, productId, safePage, safeSize);

        return new PagedResponse<MovementResponse>
        {
            Items = items.Select(m => m.ToResponse()).ToList(),
            Page = safePage,
            PageSize = safeSize,
            TotalItems = totalItems,
            TotalPages = Paging.TotalPages(totalItems, safeSize)
        };
    }

    public async Task<PagedResponse<MovementResponse>> GetAllAsync(int page, int pageSize)
    {
        var (safePage, safeSize) = Paging.Normalize(page, pageSize, defaultPageSize: 20);
        var (items, totalItems) = await _movementRepository.GetPagedAsync(
            _currentUser.UserId, safePage, safeSize);

        return new PagedResponse<MovementResponse>
        {
            Items = items.Select(m => m.ToResponse()).ToList(),
            Page = safePage,
            PageSize = safeSize,
            TotalItems = totalItems,
            TotalPages = Paging.TotalPages(totalItems, safeSize)
        };
    }
}
