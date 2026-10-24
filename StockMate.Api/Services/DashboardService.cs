using StockMate.Api.DTOs;
using StockMate.Api.Repositories;

namespace StockMate.Api.Services;

public interface IDashboardService
{
    Task<DashboardSummaryResponse> GetSummaryAsync();
}

public sealed class DashboardService : IDashboardService
{
    private const int LowStockPreviewLimit = 10;

    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ICurrentUserService _currentUser;

    public DashboardService(
        IProductRepository productRepository,
        ICategoryRepository categoryRepository,
        ICurrentUserService currentUser)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;
        _currentUser = currentUser;
    }

    public async Task<DashboardSummaryResponse> GetSummaryAsync()
    {
        var userId = _currentUser.UserId;
        var stats = await _productRepository.GetStatsAsync(userId);
        var categories = await _categoryRepository.CountAsync(userId);
        var lowStock = await _productRepository.GetLowStockAsync(userId, LowStockPreviewLimit);

        return new DashboardSummaryResponse
        {
            ActiveProducts = stats.ActiveProducts,
            Categories = categories,
            TotalStockUnits = stats.TotalStockUnits,
            LowStockProducts = stats.LowStockProducts,
            LowStockItems = lowStock.Select(p => p.ToLowStockItem()).ToList()
        };
    }
}
