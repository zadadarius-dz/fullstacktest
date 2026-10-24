using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockMate.Api.DTOs;
using StockMate.Api.Services;

namespace StockMate.Api.Controllers;

[ApiController]
[Route("api/products/{productId:guid}/movements")]
[Authorize]
[Produces("application/json")]
public sealed class ProductMovementsController : ControllerBase
{
    private readonly IStockMovementService _movementService;

    public ProductMovementsController(IStockMovementService movementService) => _movementService = movementService;

    /// <summary>Mencatat stok masuk (IN) atau keluar (OUT) secara atomik.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(MovementResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MovementResponse>> Create(
        Guid productId,
        [FromBody] CreateMovementRequest request)
    {
        var created = await _movementService.CreateAsync(productId, request);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Riwayat pergerakan stok untuk satu produk.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResponse<MovementResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PagedResponse<MovementResponse>>> GetHistory(
        Guid productId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        return Ok(await _movementService.GetByProductAsync(productId, page, pageSize));
    }
}
