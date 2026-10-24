using StockMate.Api.DTOs;
using StockMate.Api.Models;

namespace StockMate.Api.Services;

public static class Mapping
{
    public static UserResponse ToResponse(this User user) => new()
    {
        Id = user.Id,
        Name = user.Name,
        Email = user.Email,
        CreatedAt = user.CreatedAt
    };

    public static CategoryResponse ToResponse(this Category category) => new()
    {
        Id = category.Id,
        Name = category.Name,
        CreatedAt = category.CreatedAt,
        UpdatedAt = category.UpdatedAt
    };

    public static ProductResponse ToResponse(this Product product) => new()
    {
        Id = product.Id,
        Sku = product.Sku,
        Name = product.Name,
        CategoryId = product.CategoryId,
        CategoryName = product.CategoryName,
        Description = product.Description,
        Price = product.Price,
        StockQuantity = product.StockQuantity,
        MinStock = product.MinStock,
        IsActive = product.IsActive,
        CreatedAt = product.CreatedAt,
        UpdatedAt = product.UpdatedAt
    };

    public static MovementResponse ToResponse(this StockMovement movement) => new()
    {
        Id = movement.Id,
        ProductId = movement.ProductId,
        ProductSku = movement.ProductSku,
        ProductName = movement.ProductName,
        Type = movement.Type,
        Quantity = movement.Quantity,
        StockBefore = movement.StockBefore,
        StockAfter = movement.StockAfter,
        Note = movement.Note,
        CreatedAt = movement.CreatedAt
    };

    public static LowStockItem ToLowStockItem(this Product product) => new()
    {
        Id = product.Id,
        Sku = product.Sku,
        Name = product.Name,
        StockQuantity = product.StockQuantity,
        MinStock = product.MinStock
    };
}
