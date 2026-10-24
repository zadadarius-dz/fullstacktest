using System.ComponentModel.DataAnnotations;

namespace StockMate.Api.DTOs;

public sealed class RegisterRequest
{
    [Required(ErrorMessage = "Nama wajib diisi.")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Nama harus 2-100 karakter.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email wajib diisi.")]
    [EmailAddress(ErrorMessage = "Format email tidak valid.")]
    [StringLength(255, ErrorMessage = "Email maksimal 255 karakter.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Password wajib diisi.")]
    [StringLength(72, MinimumLength = 8, ErrorMessage = "Password harus 8-72 karakter.")]
    public string Password { get; set; } = string.Empty;
}

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Email wajib diisi.")]
    [EmailAddress(ErrorMessage = "Format email tidak valid.")]
    [StringLength(255, ErrorMessage = "Email maksimal 255 karakter.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Password wajib diisi.")]
    [StringLength(72, ErrorMessage = "Password maksimal 72 karakter.")]
    public string Password { get; set; } = string.Empty;
}

public sealed class UserResponse
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public DateTimeOffset CreatedAt { get; init; }
}

public sealed class AuthResponse
{
    public string AccessToken { get; init; } = string.Empty;
    public string TokenType { get; init; } = "Bearer";
    public DateTimeOffset ExpiresAt { get; init; }
    public UserResponse User { get; init; } = new();
}
