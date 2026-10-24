using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;
using Serilog.Events;
using StockMate.Api.Data;
using StockMate.Api.Middleware;
using StockMate.Api.Repositories;
using StockMate.Api.Services;

// Dapper: map kolom snake_case (PostgreSQL) ke properti PascalCase.
DefaultTypeMap.MatchNamesWithUnderscores = true;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((context, services, configuration) => configuration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext());

    // ---------------------------------------------------------------------
    // Konfigurasi JWT. Signing key TIDAK boleh berada di source control.
    // ---------------------------------------------------------------------
    var signingKey = builder.Configuration["Jwt:SigningKey"];
    if (string.IsNullOrWhiteSpace(signingKey))
    {
        signingKey = Environment.GetEnvironmentVariable("JWT_SIGNING_KEY");
    }

    var ephemeralSigningKey = false;
    if (string.IsNullOrWhiteSpace(signingKey))
    {
        if (!builder.Environment.IsDevelopment())
        {
            throw new InvalidOperationException(
                "JWT signing key belum dikonfigurasi. Set environment variable 'Jwt__SigningKey' " +
                "(atau 'JWT_SIGNING_KEY') minimal 32 karakter sebelum menjalankan API di Production.");
        }

        signingKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        ephemeralSigningKey = true;
    }

    if (Encoding.UTF8.GetByteCount(signingKey) < 32)
    {
        throw new InvalidOperationException("JWT signing key minimal 32 karakter.");
    }

    var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
    jwtOptions.SigningKey = signingKey;
    if (jwtOptions.ExpiryMinutes <= 0)
    {
        jwtOptions.ExpiryMinutes = 120;
    }

    // ---------------------------------------------------------------------
    // Services
    // ---------------------------------------------------------------------
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddHttpContextAccessor();

    builder.Services.Configure<ApiBehaviorOptions>(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var problem = new ValidationProblemDetails(context.ModelState)
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Validasi gagal",
                Detail = "Periksa kembali data yang dikirim.",
                Instance = context.HttpContext.Request.Path
            };
            problem.Extensions["traceId"] = context.HttpContext.TraceIdentifier;

            return new BadRequestObjectResult(problem)
            {
                ContentTypes = { "application/problem+json" }
            };
        };
    });

    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "StockMate API",
            Version = "v1",
            Description = "REST API manajemen inventaris StockMate. Semua endpoint selain register/login memerlukan JWT Bearer token."
        });

        options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "Masukkan access token JWT (tanpa prefix 'Bearer ')."
        });

        options.AddSecurityRequirement(new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                },
                Array.Empty<string>()
            }
        });
    });

    var allowedOrigins = builder.Configuration
        .GetSection("Cors:AllowedOrigins")
        .Get<string[]>() ?? Array.Empty<string>();

    builder.Services.AddCors(options =>
    {
        options.AddPolicy("WebApp", policy =>
        {
            if (allowedOrigins.Length > 0)
            {
                policy.WithOrigins(allowedOrigins);
            }

            policy.AllowAnyHeader().AllowAnyMethod();
        });
    });

    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.MapInboundClaims = false;
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey)),
                ValidateIssuer = true,
                ValidIssuer = jwtOptions.Issuer,
                ValidateAudience = true,
                ValidAudience = jwtOptions.Audience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromSeconds(30),
                NameClaimType = "name"
            };

            options.Events = new JwtBearerEvents
            {
                OnChallenge = async context =>
                {
                    context.HandleResponse();
                    if (context.Response.HasStarted)
                    {
                        return;
                    }

                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    context.Response.ContentType = "application/problem+json; charset=utf-8";

                    var problem = new ProblemDetails
                    {
                        Status = StatusCodes.Status401Unauthorized,
                        Title = "Tidak terautentikasi",
                        Detail = "Token tidak ada, tidak valid, atau sudah kedaluwarsa.",
                        Instance = context.Request.Path
                    };
                    problem.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
                    await context.Response.WriteAsJsonAsync(problem);
                },
                OnForbidden = async context =>
                {
                    if (context.Response.HasStarted)
                    {
                        return;
                    }

                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    context.Response.ContentType = "application/problem+json; charset=utf-8";

                    var problem = new ProblemDetails
                    {
                        Status = StatusCodes.Status403Forbidden,
                        Title = "Akses ditolak",
                        Detail = "Anda tidak memiliki izin untuk mengakses resource ini.",
                        Instance = context.Request.Path
                    };
                    problem.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
                    await context.Response.WriteAsJsonAsync(problem);
                }
            };
        });

    builder.Services.AddAuthorization();

    builder.Services.AddHealthChecks()
        .AddCheck<DatabaseHealthCheck>("database", tags: new[] { "db" });

    builder.Services.AddSingleton<IDbConnectionFactory, NpgsqlConnectionFactory>();
    builder.Services.AddSingleton(jwtOptions);
    builder.Services.AddSingleton<ITokenService, JwtTokenService>();
    builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();

    builder.Services.AddScoped<IUserRepository, UserRepository>();
    builder.Services.AddScoped<ICategoryRepository, CategoryRepository>();
    builder.Services.AddScoped<IProductRepository, ProductRepository>();
    builder.Services.AddScoped<IStockMovementRepository, StockMovementRepository>();

    builder.Services.AddScoped<IAuthService, AuthService>();
    builder.Services.AddScoped<ICategoryService, CategoryService>();
    builder.Services.AddScoped<IProductService, ProductService>();
    builder.Services.AddScoped<IStockMovementService, StockMovementService>();
    builder.Services.AddScoped<IDashboardService, DashboardService>();

    builder.Services.AddTransient<DatabaseMigrator>();
    builder.Services.AddTransient<DatabaseHealthCheck>();

    var app = builder.Build();

    if (ephemeralSigningKey)
    {
        app.Logger.LogWarning(
            "JWT signing key tidak dikonfigurasi. Menggunakan key ephemeral in-memory untuk Development; " +
            "token akan tidak valid setelah API restart. Set 'Jwt__SigningKey' untuk penggunaan nyata.");
    }

    if (app.Configuration.GetValue<bool>("Database:AutoMigrate"))
    {
        await using var scope = app.Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<DatabaseMigrator>().ApplyAsync();
    }

    app.UseSerilogRequestLogging(options =>
    {
        options.MessageTemplate =
            "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000} ms";
        options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
        {
            diagnosticContext.Set("RequestId", httpContext.TraceIdentifier);
        };
    });

    app.UseMiddleware<ExceptionHandlingMiddleware>();

    var swaggerEnabled = app.Environment.IsDevelopment() ||
                         app.Configuration.GetValue<bool>("Swagger:Enabled");

    if (swaggerEnabled)
    {
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/swagger/v1/swagger.json", "StockMate API v1");
            options.DocumentTitle = "StockMate API";
        });
    }

    app.UseCors("WebApp");
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();
    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = HealthCheckResponseWriter.WriteAsync
    });

    if (swaggerEnabled)
    {
        app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();
    }

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Aplikasi berhenti karena error yang tidak tertangani.");
    throw;
}
finally
{
    Log.CloseAndFlush();
}

public partial class Program
{
}
