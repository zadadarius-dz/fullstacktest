using System.Text;
using StockMate.Api.DTOs;
using StockMate.Api.Models;
using StockMate.Api.Repositories;
using StockMate.Api.Services.Exceptions;

namespace StockMate.Api.Services;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request);
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<UserResponse> GetCurrentUserAsync();
}

public sealed class AuthService : IAuthService
{
    private const int BCryptWorkFactor = 12;
    private const int BCryptMaxPasswordBytes = 72;

    private readonly IUserRepository _userRepository;
    private readonly ITokenService _tokenService;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IUserRepository userRepository,
        ITokenService tokenService,
        ICurrentUserService currentUser,
        ILogger<AuthService> logger)
    {
        _userRepository = userRepository;
        _tokenService = tokenService;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        var name = (request.Name ?? string.Empty).Trim();
        var email = NormalizeEmail(request.Email);
        ValidatePassword(request.Password);

        if (name.Length < 2 || name.Length > 100)
        {
            throw new BadRequestException("Nama harus 2-100 karakter.");
        }

        if (await _userRepository.EmailExistsAsync(email))
        {
            throw new ConflictException("Email sudah terdaftar.");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Name = name,
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password, BCryptWorkFactor)
        };

        var created = await _userRepository.CreateAsync(user);
        _logger.LogInformation("Pengguna baru terdaftar: {UserId}", created.Id);

        return BuildAuthResponse(created);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var email = NormalizeEmail(request.Email);
        var user = await _userRepository.GetByEmailAsync(email);

        if (user is null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            throw new UnauthorizedException("Email atau password salah.");
        }

        _logger.LogInformation("Pengguna login: {UserId}", user.Id);
        return BuildAuthResponse(user);
    }

    public async Task<UserResponse> GetCurrentUserAsync()
    {
        var user = await _userRepository.GetByIdAsync(_currentUser.UserId);
        if (user is null)
        {
            throw new UnauthorizedException("Akun pengguna tidak ditemukan.");
        }

        return user.ToResponse();
    }

    private AuthResponse BuildAuthResponse(User user)
    {
        var (token, expiresAt) = _tokenService.CreateToken(user);
        return new AuthResponse
        {
            AccessToken = token,
            TokenType = "Bearer",
            ExpiresAt = expiresAt,
            User = user.ToResponse()
        };
    }

    private static string NormalizeEmail(string email) => (email ?? string.Empty).Trim().ToLowerInvariant();

    private static void ValidatePassword(string password)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length < 8)
        {
            throw new BadRequestException("Password minimal 8 karakter.");
        }

        // BCrypt hanya memproses maksimal 72 byte; tolak lebih awal agar tidak terpotong diam-diam.
        if (Encoding.UTF8.GetByteCount(password) > BCryptMaxPasswordBytes)
        {
            throw new BadRequestException("Password terlalu panjang (maksimal 72 byte).");
        }
    }
}
