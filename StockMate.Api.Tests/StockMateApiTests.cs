using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace StockMate.Api.Tests;

public sealed class StockMateApiTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private static readonly Lazy<ApiFactory> SharedFactory = new(() =>
        new ApiFactory(TestEnvironment.ConnectionString!));

    [SkippableFact]
    public async Task Auth_Register_Login_And_Protected_Endpoints_Work()
    {
        TestEnvironment.RequireDatabase();
        using var anonymous = SharedFactory.Value.CreateClient();

        var email = UniqueEmail();
        var registerResponse = await anonymous.PostAsJsonAsync("/api/auth/register", new
        {
            name = "Pengguna Uji",
            email = email.ToUpperInvariant(),
            password = "Password123!"
        });

        Assert.Equal(HttpStatusCode.Created, registerResponse.StatusCode);
        var auth = await registerResponse.Content.ReadFromJsonAsync<AuthDto>(JsonOptions);
        Assert.NotNull(auth);
        Assert.False(string.IsNullOrWhiteSpace(auth!.AccessToken));
        Assert.Equal(email, auth.User.Email);
        Assert.Equal("Bearer", auth.TokenType);

        var raw = await registerResponse.Content.ReadAsStringAsync();
        Assert.DoesNotContain("password", raw, StringComparison.OrdinalIgnoreCase);

        var loginResponse = await anonymous.PostAsJsonAsync("/api/auth/login", new
        {
            email = email,
            password = "Password123!"
        });
        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);

        using var authorized = CreateClient(auth.AccessToken);
        var meResponse = await authorized.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, meResponse.StatusCode);

        var unauthorized = await anonymous.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, unauthorized.StatusCode);

        using var invalidTokenClient = CreateClient("not-a-real-token");
        var invalid = await invalidTokenClient.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, invalid.StatusCode);
    }

    [SkippableFact]
    public async Task Auth_Rejects_Invalid_Input()
    {
        TestEnvironment.RequireDatabase();
        using var client = SharedFactory.Value.CreateClient();

        var badEmail = await client.PostAsJsonAsync("/api/auth/register", new
        {
            name = "A",
            email = "bukan-email",
            password = "123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, badEmail.StatusCode);

        var badLogin = await client.PostAsJsonAsync("/api/auth/login", new
        {
            email = "tidak-ada@example.com",
            password = "Password123!"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, badLogin.StatusCode);
    }

    [SkippableFact]
    public async Task Categories_Crud_And_Duplicate_Name_Conflict()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var created = await CreateCategoryAsync(client, "Makanan");
        Assert.NotEqual(Guid.Empty, created.Id);

        var duplicate = await client.PostAsJsonAsync("/api/categories", new { name = "makanan" });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var updated = await client.PutAsJsonAsync($"/api/categories/{created.Id}", new { name = "Makanan Ringan" });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var updatedCategory = await updated.Content.ReadFromJsonAsync<CategoryDto>(JsonOptions);
        Assert.Equal("Makanan Ringan", updatedCategory!.Name);

        var list = await client.GetFromJsonAsync<List<CategoryDto>>("/api/categories", JsonOptions);
        Assert.Contains(list!, c => c.Id == created.Id);

        var delete = await client.DeleteAsync($"/api/categories/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);

        var afterDelete = await client.GetAsync($"/api/categories/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, afterDelete.StatusCode);
    }

    [SkippableFact]
    public async Task Category_In_Use_Cannot_Be_Deleted()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var category = await CreateCategoryAsync(client, "Kategori Terpakai");
        await CreateProductAsync(client, category.Id, "USED-001");

        var delete = await client.DeleteAsync($"/api/categories/{category.Id}");
        Assert.Equal(HttpStatusCode.Conflict, delete.StatusCode);

        var stillThere = await client.GetAsync($"/api/categories/{category.Id}");
        Assert.Equal(HttpStatusCode.OK, stillThere.StatusCode);
    }

    [SkippableFact]
    public async Task Products_Start_At_Zero_Update_Keeps_Stock_And_Delete_Is_Soft()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var category = await CreateCategoryAsync(client, "Elektronik");
        var product = await CreateProductAsync(client, category.Id, "sku-abc-001", minStock: 5);
        Assert.Equal(0, product.StockQuantity);
        Assert.Equal("SKU-ABC-001", product.Sku);
        Assert.True(product.IsActive);

        var movement = await client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
        {
            type = "IN",
            quantity = 5,
            note = "Stok awal"
        });
        Assert.Equal(HttpStatusCode.Created, movement.StatusCode);

        var update = await client.PutAsJsonAsync($"/api/products/{product.Id}", new
        {
            sku = "sku-abc-001",
            name = "Produk Diperbarui",
            categoryId = category.Id,
            description = "Deskripsi baru",
            price = 125000,
            minStock = 2,
            isActive = true
        });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        var updated = await update.Content.ReadFromJsonAsync<ProductDto>(JsonOptions);
        Assert.Equal("Produk Diperbarui", updated!.Name);
        Assert.Equal(5, updated.StockQuantity);
        Assert.Equal(125000, updated.Price);

        var duplicateSku = await client.PostAsJsonAsync("/api/products", new
        {
            sku = "SKU-ABC-001",
            name = "SKU Duplikat",
            categoryId = category.Id,
            price = 1,
            minStock = 0
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicateSku.StatusCode);

        var delete = await client.DeleteAsync($"/api/products/{product.Id}");
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);

        var getAfterDelete = await client.GetAsync($"/api/products/{product.Id}");
        Assert.Equal(HttpStatusCode.NotFound, getAfterDelete.StatusCode);

        var list = await client.GetFromJsonAsync<PagedDto<ProductDto>>("/api/products", JsonOptions);
        Assert.DoesNotContain(list!.Items, p => p.Id == product.Id);

        var history = await client.GetFromJsonAsync<PagedDto<MovementDto>>(
            $"/api/products/{product.Id}/movements", JsonOptions);
        Assert.Single(history!.Items);
    }

    [SkippableFact]
    public async Task Movements_Reject_NonPositive_Quantity_And_Oversell()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var category = await CreateCategoryAsync(client, "ATK");
        var product = await CreateProductAsync(client, category.Id, "ATK-001");

        var zero = await client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
        {
            type = "IN",
            quantity = 0
        });
        Assert.Equal(HttpStatusCode.BadRequest, zero.StatusCode);

        var negative = await client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
        {
            type = "OUT",
            quantity = -3
        });
        Assert.Equal(HttpStatusCode.BadRequest, negative.StatusCode);

        var oversell = await client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
        {
            type = "OUT",
            quantity = 1
        });
        Assert.Equal(HttpStatusCode.Conflict, oversell.StatusCode);

        var detail = await client.GetFromJsonAsync<ProductDto>($"/api/products/{product.Id}", JsonOptions);
        Assert.Equal(0, detail!.StockQuantity);

        var history = await client.GetFromJsonAsync<PagedDto<MovementDto>>(
            $"/api/products/{product.Id}/movements", JsonOptions);
        Assert.Empty(history!.Items);
    }

    [SkippableFact]
    public async Task User_Cannot_Access_Another_Users_Data()
    {
        TestEnvironment.RequireDatabase();
        var ownerAuth = await RegisterAsync();
        using var owner = CreateClient(ownerAuth.AccessToken);

        var category = await CreateCategoryAsync(owner, "Milik A");
        var product = await CreateProductAsync(owner, category.Id, "PRIVATE-001");
        await owner.PostAsJsonAsync($"/api/products/{product.Id}/movements", new { type = "IN", quantity = 7 });

        var otherAuth = await RegisterAsync();
        using var other = CreateClient(otherAuth.AccessToken);

        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/categories/{category.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PutAsJsonAsync($"/api/categories/{category.Id}", new { name = "Diubah" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.DeleteAsync($"/api/categories/{category.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/products/{product.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/products/{product.Id}/movements")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsJsonAsync($"/api/products/{product.Id}/movements", new { type = "OUT", quantity = 1 })).StatusCode);

        var otherProducts = await other.GetFromJsonAsync<PagedDto<ProductDto>>("/api/products", JsonOptions);
        Assert.Empty(otherProducts!.Items);

        var otherMovements = await other.GetFromJsonAsync<PagedDto<MovementDto>>("/api/stock-movements", JsonOptions);
        Assert.Empty(otherMovements!.Items);
    }

    [SkippableFact]
    public async Task Dashboard_Reflects_Inventory()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var category = await CreateCategoryAsync(client, "Dashboard");
        var low = await CreateProductAsync(client, category.Id, "LOW-001", minStock: 5);
        var healthy = await CreateProductAsync(client, category.Id, "OK-001", minStock: 1);

        await client.PostAsJsonAsync($"/api/products/{low.Id}/movements", new { type = "IN", quantity = 2 });
        await client.PostAsJsonAsync($"/api/products/{healthy.Id}/movements", new { type = "IN", quantity = 10 });

        var dashboard = await client.GetFromJsonAsync<DashboardDto>("/api/dashboard/summary", JsonOptions);
        Assert.NotNull(dashboard);
        Assert.Equal(2, dashboard!.ActiveProducts);
        Assert.Equal(1, dashboard.Categories);
        Assert.Equal(12, dashboard.TotalStockUnits);
        Assert.Equal(1, dashboard.LowStockProducts);
        Assert.Single(dashboard.LowStockItems);
        Assert.Equal("LOW-001", dashboard.LowStockItems[0].Sku);
    }

    [SkippableFact]
    public async Task Concurrent_Out_Requests_Never_Oversell()
    {
        TestEnvironment.RequireDatabase();
        var auth = await RegisterAsync();
        using var client = CreateClient(auth.AccessToken);

        var category = await CreateCategoryAsync(client, "Concurrency");
        var product = await CreateProductAsync(client, category.Id, "CONC-001");

        var stockIn = await client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
        {
            type = "IN",
            quantity = 10
        });
        Assert.Equal(HttpStatusCode.Created, stockIn.StatusCode);

        var requests = Enumerable.Range(0, 20).Select(_ =>
            client.PostAsJsonAsync($"/api/products/{product.Id}/movements", new
            {
                type = "OUT",
                quantity = 1,
                note = "parallel"
            }));

        var responses = await Task.WhenAll(requests);
        var successes = responses.Count(r => r.StatusCode == HttpStatusCode.Created);
        var conflicts = responses.Count(r => r.StatusCode == HttpStatusCode.Conflict);

        Assert.Equal(10, successes);
        Assert.Equal(10, conflicts);

        var detail = await client.GetFromJsonAsync<ProductDto>($"/api/products/{product.Id}", JsonOptions);
        Assert.Equal(0, detail!.StockQuantity);

        var history = await client.GetFromJsonAsync<PagedDto<MovementDto>>(
            $"/api/products/{product.Id}/movements?pageSize=100", JsonOptions);
        Assert.Equal(11, history!.TotalItems);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static HttpClient CreateClient(string token)
    {
        var client = SharedFactory.Value.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    private static async Task<AuthDto> RegisterAsync()
    {
        using var client = SharedFactory.Value.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/register", new
        {
            name = "Pengguna Uji",
            email = UniqueEmail(),
            password = "Password123!"
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<AuthDto>(JsonOptions);
        Assert.NotNull(auth);
        return auth!;
    }

    private static async Task<CategoryDto> CreateCategoryAsync(HttpClient client, string name)
    {
        var response = await client.PostAsJsonAsync("/api/categories", new { name });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var category = await response.Content.ReadFromJsonAsync<CategoryDto>(JsonOptions);
        Assert.NotNull(category);
        return category!;
    }

    private static async Task<ProductDto> CreateProductAsync(
        HttpClient client, Guid categoryId, string sku, int minStock = 0)
    {
        var response = await client.PostAsJsonAsync("/api/products", new
        {
            sku,
            name = "Produk Uji",
            categoryId,
            description = "Dibuat oleh integration test",
            price = 10000,
            minStock
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var product = await response.Content.ReadFromJsonAsync<ProductDto>(JsonOptions);
        Assert.NotNull(product);
        return product!;
    }

    private static string UniqueEmail()
        => $"test-{Guid.NewGuid():N}@example.com";
}

internal static class TestEnvironment
{
    public static string? ConnectionString
        => Environment.GetEnvironmentVariable("STOCKMATE_TEST_DATABASE");

    public static void RequireDatabase()
    {
        Skip.If(
            string.IsNullOrWhiteSpace(ConnectionString),
            "Set STOCKMATE_TEST_DATABASE ke connection string PostgreSQL yang dapat ditulis. " +
            "Contoh: Host=127.0.0.1;Port=55432;Database=stockmate_test;Username=...;Password=...");
    }
}
