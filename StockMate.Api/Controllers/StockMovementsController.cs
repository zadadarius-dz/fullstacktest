using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using StockMate.Api.DTOs;
using StockMate.Api.Services;

namespace StockMate.Api.Controllers;

[ApiController]
[Route("api/stock-movements")]
[Authorize]
[Produces("application/json")]
public sealed class StockMovementsController : ControllerBase
{
    private readonly IStockMovementService _movementService;

    public StockMovementsController(IStockMovementService movementService) => _movementService = movementService;

    /// <summary>Riwayat seluruh pergerakan stok milik pengguna.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResponse<MovementResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponse<MovementResponse>>> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        return Ok(await _movementService.GetAllAsync(page, pageSize));
    }
}
