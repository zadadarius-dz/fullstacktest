# StockMate

Monorepo **StockMate — Simple Inventory Management System**: backend REST API .NET di root, web React di `web/`, dan aplikasi Flutter di `mobile/`. API menangani autentikasi JWT, CRUD kategori dan produk, pencatatan stok masuk/keluar secara atomik, serta ringkasan dashboard. Setiap data dibatasi berdasarkan pengguna yang sedang login.

> Status verifikasi terakhir (24 Oktober 2026): `dotnet build` **0 warning / 0 error**, **9 integration test lulus**, database `stockmate` aktif dan `/health` **Healthy**, web lint bersih dan build berhasil, mobile `flutter analyze` bersih, **5/5 test lulus**, serta APK 50,0 MB terpasang dan berjalan di HP Android 14. Detail ada di [`docs/TESTING.md`](docs/TESTING.md). API dan web **belum di-deploy**; tidak ada URL publik yang diklaim.

## 1. Fitur

- Register dan login dengan password BCrypt dan access token JWT.
- CRUD kategori milik pengguna; nama unik per pengguna tanpa membedakan kapitalisasi.
- CRUD produk; SKU unik per pengguna, stok awal selalu `0`, edit produk tidak mengubah stok, delete bersifat soft delete.
- Stok masuk (`IN`) dan keluar (`OUT`) dalam satu transaksi database dengan row lock.
- Penolakan stok keluar melebihi stok tersedia (`409 Conflict`); stok tidak pernah negatif.
- Riwayat stok append-only, dapat difilter per produk atau seluruh produk pengguna.
- Dashboard: jumlah produk aktif, kategori, total unit stok, dan produk stok menipis.
- Isolasi data: `user_id` selalu diambil dari klaim JWT `sub`, bukan dari body/query.
- Error konsisten menggunakan `ProblemDetails`.
- Logging Serilog ke console dan file rolling harian.
- Swagger/OpenAPI dengan dukungan Bearer token.
- Health check database di `/health`.
- CORS eksplisit dari konfigurasi.

## 2. Stack dan versi

| Komponen | Versi / keterangan |
|---|---|
| ASP.NET Core | Target `net8.0` |
| .NET SDK terpasang saat pengembangan | **8.0.426** |
| Runtime | .NET 8.0.32 |
| PostgreSQL | 18.6 (diuji pada PostgreSQL 18) |
| Dapper | 2.1.66 |
| Npgsql | 8.0.6 |
| BCrypt.Net-Next | 4.0.3 |
| Serilog.AspNetCore | 8.0.3 |
| Swashbuckle.AspNetCore | 6.6.2 |
| JWT Bearer | Microsoft.AspNetCore.Authentication.JwtBearer 8.0.11 |

### Catatan .NET 10

PRD merekomendasikan **.NET 10 LTS** untuk proyek baru. Mesin pengembangan ini hanya memiliki SDK **8.0.426**, sehingga proyek untuk sementara menargetkan `net8.0` dan seluruh paket memakai versi 8.x yang kompatibel. Sebelum rilis produksi:

1. Pasang .NET 10 SDK.
2. Ubah `TargetFramework` di `StockMate.Api/StockMate.Api.csproj` dan `StockMate.Api.Tests/StockMate.Api.Tests.csproj` menjadi `net10.0`.
3. Perbarui paket ke versi 10.x yang sesuai.
4. Jalankan `dotnet restore`, `dotnet build`, dan `dotnet test` ulang.
5. Perbarui dokumentasi versi.

Jangan mencampur target framework dan versi paket tanpa build/test.

## 3. Prasyarat

- Windows, Linux, atau macOS dengan .NET SDK 8.0 atau lebih baru (sesuai target saat ini).
- PostgreSQL 13+ (disarankan 18.x).
- `psql` atau pgAdmin untuk menjalankan schema.
- Git.
- Port default API: `5131` (dapat diubah melalui `ASPNETCORE_URLS`).

## 4. Setup lokal dari clone bersih

```powershell
git clone https://github.com/zadadarius-dz/fullstacktest.git
cd fullstacktest
dotnet restore StockMate.sln
dotnet build StockMate.sln
```

Repository ini adalah monorepo berisi backend, web, dan mobile:

## 5. Konfigurasi environment

**Jangan menulis password database, JWT signing key, atau token ke source control.** Gunakan environment variable, user-secrets untuk development, atau secret manager pada hosting. Contoh placeholder tersedia di [`.env.example`](.env.example).

| Variabel | Wajib | Contoh / keterangan |
|---|---|---|
| `ConnectionStrings__DefaultConnection` | Ya | `Host=localhost;Port=5432;Database=stockmate;Username=stockmate_app;Password=<password-anda>` |
| `DATABASE_URL` | Alternatif | Format `postgres://user:pass@host:5432/db`; dipakai bila connection string biasa kosong. |
| `Jwt__SigningKey` atau `JWT_SIGNING_KEY` | Ya untuk Production | Minimal 32 karakter acak. Di Development, bila kosong, API membuat key ephemeral in-memory. |
| `Jwt__Issuer` | Tidak | Default `StockMate.Api`. |
| `Jwt__Audience` | Tidak | Default `StockMate.Clients`. |
| `Jwt__ExpiryMinutes` | Tidak | Default `120`. |
| `Cors__AllowedOrigins__0` | Tidak | Default development: `http://localhost:5173`. Tambahkan origin web lain dengan indeks berikutnya. |
| `Database__AutoMigrate` | Tidak | `true` untuk menjalankan schema otomatis saat API start. Default `false`. |
| `Swagger__Enabled` | Tidak | `true` untuk mengaktifkan Swagger di luar Development. Default `false` di Production. |
| `ASPNETCORE_ENVIRONMENT` | Ya | `Development` atau `Production`. |
| `ASPNETCORE_URLS` | Tidak | Contoh `http://localhost:5131`. |

### Contoh PowerShell (nilai diisi sendiri, jangan di-commit)

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:ASPNETCORE_URLS = 'http://localhost:5131'
$env:ConnectionStrings__DefaultConnection = 'Host=localhost;Port=5432;Database=stockmate;Username=stockmate_app;Password=<password-anda>'
$env:Jwt__SigningKey = '<minimal-32-karakter-acak>'
dotnet run --project StockMate.Api
```

### User-secrets untuk Development

```powershell
dotnet user-secrets init --project StockMate.Api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=stockmate;Username=stockmate_app;Password=<password-anda>" --project StockMate.Api
dotnet user-secrets set "Jwt:SigningKey" "<minimal-32-karakter-acak>" --project StockMate.Api
dotnet run --project StockMate.Api
```

Nilai user-secrets disimpan di profil pengguna, bukan di repository.

### Perilaku JWT di Development

Bila `Jwt__SigningKey`/`JWT_SIGNING_KEY` tidak diisi dan environment adalah Development, API membuat signing key acak in-memory dan menulis peringatan di log. Token akan tidak valid setelah API restart. Untuk penggunaan nyata, selalu set key dari environment/secret manager. Di Production, API gagal start bila key tidak ada atau kurang dari 32 karakter.

## 6. Menyiapkan database

### 6.1 Membuat role dan database

Jalankan `psql` sebagai superuser. Contoh di Windows:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -p 5432
```

Di prompt psql:

```sql
CREATE ROLE stockmate_app LOGIN;
\password stockmate_app
CREATE DATABASE stockmate OWNER stockmate_app;
\q
```

`\password` akan meminta password baru secara interaktif. Password tidak ditulis di file atau dokumentasi.

Alternatif melalui pgAdmin:

1. Buka pgAdmin dan hubungkan ke instance PostgreSQL.
2. Buat role/login `stockmate_app`.
3. Buat database `stockmate` dengan owner `stockmate_app`.
4. Simpan password di password manager dan isi connection string melalui environment variable.

### 6.2 Menjalankan schema

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h localhost -p 5432 -U stockmate_app -d stockmate `
  -f "C:\projects\stockmate\StockMate.Api\Data\Migrations\001_initial_schema.sql"
```

`psql` akan meminta password. Script schema bersifat **idempoten** dan aman dijalankan ulang. Script tidak membuat database dan tidak berisi credential.

Melalui pgAdmin: buka database `stockmate` → Query Tool → buka file `StockMate.Api/Data/Migrations/001_initial_schema.sql` → Execute.

### 6.3 Auto-migrate

Alternatif, set `Database__AutoMigrate=true` sebelum menjalankan API. API akan menjalankan file schema yang sama saat start. Untuk produksi, pertimbangkan menjalankan migration sebagai langkah deployment terpisah agar perubahan schema lebih terkontrol.

### 6.4 Verifikasi tabel

```sql
\dt
```

Harus muncul `users`, `categories`, `products`, dan `stock_movements`. Detail schema, constraint, index, dan ERD ada di [`docs/DATABASE.md`](docs/DATABASE.md).

## 7. Menjalankan API

```powershell
dotnet run --project StockMate.Api
```

- Swagger UI: `http://localhost:5131/swagger`
- Health check: `http://localhost:5131/health`
- Root akan redirect ke Swagger bila Swagger aktif.

Contoh cepat dengan curl (token diisi setelah login):

```bash
curl -X POST http://localhost:5131/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Contoh Pengguna","email":"contoh@example.com","password":"Password123!"}'
```

Simpan `accessToken`, lalu:

```bash
curl http://localhost:5131/api/dashboard/summary \
  -H "Authorization: Bearer $TOKEN"
```

Dokumentasi endpoint lengkap: [`docs/API.md`](docs/API.md).

## 8. Build dan test

```powershell
dotnet build StockMate.sln
```

Integration test membutuhkan database PostgreSQL yang dapat ditulis. Set `STOCKMATE_TEST_DATABASE` ke database **khusus test**:

```powershell
$env:STOCKMATE_TEST_DATABASE = 'Host=localhost;Port=5432;Database=stockmate_test;Username=stockmate_app;Password=<password-anda>'
dotnet test StockMate.sln --logger "console;verbosity=normal"
```

Bila `STOCKMATE_TEST_DATABASE` tidak diisi, test integration akan di-skip (bukan gagal) dengan pesan yang menjelaskan cara mengisinya. Test factory mengaktifkan auto-migrate untuk database test. **Jangan arahkan test ke database produksi.**

Hasil verifikasi terakhir di mesin pengembangan: **9/9 test lulus** menggunakan cluster PostgreSQL sementara. Rincian ada di [`docs/TESTING.md`](docs/TESTING.md).

## 9. Struktur proyek (monorepo)

```text
StockMate.sln
StockMate.Api/
  Controllers/        Auth, Categories, Products, ProductMovements, StockMovements, Dashboard
  DTOs/               Request/response dan pagination
  Models/             User, Category, Product, StockMovement
  Repositories/       Dapper + Npgsql, query berparameter
  Services/           Aturan bisnis, JWT, current user, mapping
  Data/               Connection factory, health check, migrator, Migrations/
  Middleware/         Global exception handler (ProblemDetails)
  Properties/         launchSettings.json
  Program.cs
  appsettings.json
StockMate.Api.Tests/  Integration test (xUnit + WebApplicationFactory)
web/                  Aplikasi React + Vite (lihat web/README.md)
mobile/               Aplikasi Flutter (lihat mobile/README.md)
docs/                 API, DATABASE, DEPLOYMENT, TESTING, IMPLEMENTATION_PLAN
```

Perintah backend dijalankan dari root repository. Perintah web dijalankan dari `web/`, dan perintah Flutter dari `mobile/`.

Alur request: `Controller → Service → Repository → PostgreSQL`. Controller hanya menangani HTTP; aturan bisnis ada di service; SQL dan transaksi ada di repository.

## 10. Aturan bisnis penting

- `user_id` untuk semua query berasal dari `ICurrentUserService` yang membaca klaim `sub` dari JWT.
- Kategori tidak dapat dihapus bila masih dipakai produk; API mengembalikan `409`.
- SKU di-trim dan diubah ke uppercase sebelum disimpan; unik per pengguna.
- Produk baru selalu memiliki `stock_quantity = 0`; nilai stok tidak diterima dari request create.
- `PUT /api/products/{id}` tidak menyentuh `stock_quantity`.
- `DELETE /api/products/{id}` hanya mengubah `is_active = false`.
- Movement `OUT` yang melebihi stok ditolak `409`; update stok dan insert riwayat berada dalam satu transaksi dengan `SELECT ... FOR UPDATE`.
- Riwayat movement tidak memiliki endpoint update/delete.

## 11. Deployment

Ringkasan langkah deployment ada di [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md). API belum di-deploy, sehingga URL publik belum tersedia.

- Backend dapat dijalankan sebagai Kestrel service di balik reverse proxy HTTPS, container, atau host ASP.NET Core.
- Database menggunakan PostgreSQL ter-host.
- Set seluruh environment variable di hosting; jangan mengandalkan `appsettings.json` untuk secret.
- Batasi CORS ke origin web yang benar.
- Aktifkan HTTPS dan jangan mengekspos Swagger di Production tanpa perlindungan bila tidak diperlukan.

## 12. Troubleshooting

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| `Connection string PostgreSQL belum dikonfigurasi` | Env var belum diisi | Set `ConnectionStrings__DefaultConnection` atau `DATABASE_URL`. |
| `fe_sendauth: no password supplied` | `psql` tidak mendapat password | Biarkan `psql` meminta password; jangan menulis password di command line. |
| `password authentication failed` | Password/role salah | Periksa role, database, dan connection string. |
| `42P01: relation "users" does not exist` | Schema belum dijalankan | Jalankan `001_initial_schema.sql` atau set `Database__AutoMigrate=true`. |
| `401 Unauthorized` di endpoint terproteksi | Token tidak ada/kedaluwarsa/key berbeda | Login ulang; pastikan `Jwt__SigningKey` sama selama token berlaku. |
| `409 Conflict` saat OUT | Stok tidak mencukupi | Periksa stok terkini; ini perilaku yang benar. |
| `409 Conflict` saat hapus kategori | Kategori masih dipakai produk | Pindahkan/hapus produk terlebih dahulu. |
| Swagger tidak muncul di Production | `Swagger__Enabled` false | Aktifkan hanya bila memang diperlukan dan aman. |
| CORS error dari web | Origin tidak terdaftar | Tambahkan origin ke `Cors__AllowedOrigins__N`. |

## 13. Status deployment

| Item | Status |
|---|---|
| Build backend | Terverifikasi lokal |
| Integration test | 9/9 lulus dengan database test lokal |
| API publik | **TODO: isi setelah deploy** |
| Database produksi | **TODO: isi setelah deploy** |
| Swagger publik | **TODO: isi setelah deploy** |

Tidak ada URL deployment atau credential yang dikarang dalam dokumen ini.
