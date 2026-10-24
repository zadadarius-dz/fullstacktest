using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Services;

public interface ICurrentUserService
{
    Guid UserId { get; }
}

public sealed class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid UserId
    {
        get
        {
            var principal = _httpContextAccessor.HttpContext?.User;
            var value = principal?.FindFirstValue(JwtRegisteredClaimNames.Sub)
                        ?? principal?.FindFirstValue(ClaimTypes.NameIdentifier);

            if (!Guid.TryParse(value, out var userId))
            {
                throw new UnauthorizedException("Token tidak valid atau tidak memuat identitas pengguna.");
            }

            return userId;
        }
    }
}
