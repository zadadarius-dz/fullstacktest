# StockMate — Deployment

**Status:** panduan siap pakai, tetapi **belum ada deployment yang dilakukan**. Tidak ada URL publik, kredensial, atau hasil verifikasi produksi yang diklaim di dokumen ini.

Dokumen ini menjelaskan cara men-deploy tiga komponen StockMate:

1. PostgreSQL ter-host
2. REST API ASP.NET Core
3. Aplikasi web React (static hosting)
4. Aplikasi Android (APK) — opsional, memerlukan Flutter SDK

> Placeholder `TODO: isi setelah deploy` hanya boleh diganti setelah langkah tersebut benar-benar dijalankan dan diverifikasi.

## 1. Ringkasan arsitektur deployment

```text
Browser ──HTTPS──► Static host (React build)
                        │
                        │ HTTPS + CORS
                        ▼
                 Reverse proxy / platform
                        │
                        ▼
                 StockMate API (Kestrel)
                        │
                        │ TCP + TLS (sesuai provider)
                        ▼
                 PostgreSQL ter-host
```

Aplikasi Android berbicara langsung ke API yang sama melalui HTTPS.

## 2. Checklist sebelum deploy

- [ ] Schema `001_initial_schema.sql` sudah dijalankan pada database produksi.
- [ ] `ConnectionStrings__DefaultConnection` diisi di secret manager hosting.
- [ ] `Jwt__SigningKey` diisi minimal 32 karakter acak dan **berbeda** dari development.
- [ ] `ASPNETCORE_ENVIRONMENT=Production`.
- [ ] `Cors__AllowedOrigins__0` berisi origin web produksi (HTTPS, tanpa trailing slash).
- [ ] `Swagger__Enabled` diputuskan: `false` kecuali memang dilindungi.
- [ ] `Database__AutoMigrate=false` untuk produksi (migration dijalankan terpisah).
- [ ] HTTPS aktif di semua endpoint publik.
- [ ] Log tidak memuat password, token, atau body sensitif.
- [ ] Backup database terjadwal.
- [ ] `.env`, `appsettings.Production.json`, dan file dump tidak masuk repository.
- [ ] Build backend dan web dijalankan ulang dari commit yang akan dirilis.
- [ ] Smoke test pasca-deploy dijalankan (lihat bagian 9).

## 3. Database produksi

### 3.1 Pilihan provider

Gunakan PostgreSQL terkelola (mis. provider cloud pilihan Anda) atau server sendiri. Yang dibutuhkan:

- PostgreSQL 13+ (disarankan 18.x).
- Koneksi TLS bila melewati jaringan publik.
- Database dan role khusus aplikasi, bukan superuser.
- Backup otomatis dan point-in-time recovery bila tersedia.

### 3.2 Membuat role dan database

```sql
CREATE ROLE stockmate_app LOGIN PASSWORD '<password-kuat-dari-password-manager>';
CREATE DATABASE stockmate OWNER stockmate_app;
```

Password dibuat acak dan disimpan di password manager/secret manager. **Jangan** menuliskannya di dokumen, chat, atau repository.

### 3.3 Menjalankan schema

Dari mesin yang memiliki akses ke database:

```bash
psql "$DATABASE_URL" -f StockMate.Api/Data/Migrations/001_initial_schema.sql
```

atau melalui Query Tool provider. Script bersifat idempoten.

Verifikasi:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

Harus ada `users`, `categories`, `products`, `stock_movements`.

### 3.4 Connection string

Format umum:

```text
Host=<host>;Port=5432;Database=stockmate;Username=stockmate_app;Password=<password>;SSL Mode=Require
```

Sesuaikan `SSL Mode` dengan kebijakan provider (`Require`, `VerifyFull`, atau mode yang didukung). Alternatif: `DATABASE_URL` dalam format `postgres://user:pass@host:5432/db`.

### 3.5 Catatan provider yang membatasi koneksi

Beberapa provider membatasi jumlah koneksi. Npgsql melakukan connection pooling per proses API. Jika memakai banyak instance API, kurangi `Maximum Pool Size` pada connection string atau gunakan pgbouncer sesuai anjuran provider. Ini belum diuji dalam proyek ini; ukur sebelum menaikkan trafik.

## 4. Backend API

### 4.1 Build artefak

```bash
dotnet restore StockMate.sln
dotnet build StockMate.sln -c Release
dotnet publish StockMate.Api/StockMate.Api.csproj -c Release -o ./publish
```

Jalankan test sebelum publish:

```bash
STOCKMATE_TEST_DATABASE="<connection-string-database-test>" \
  dotnet test StockMate.sln -c Release
```

### 4.2 Environment variable produksi

| Variabel | Nilai |
|---|---|
| `ASPNETCORE_ENVIRONMENT` | `Production` |
| `ASPNETCORE_URLS` | mis. `http://0.0.0.0:8080` (sesuaikan platform) |
| `ConnectionStrings__DefaultConnection` | connection string dari secret manager |
| `Jwt__SigningKey` | minimal 32 karakter acak |
| `Jwt__Issuer` | `StockMate.Api` (atau nilai Anda) |
| `Jwt__Audience` | `StockMate.Clients` (atau nilai Anda) |
| `Jwt__ExpiryMinutes` | mis. `120` |
| `Cors__AllowedOrigins__0` | `https://<domain-web-anda>` |
| `Swagger__Enabled` | `false` |
| `Database__AutoMigrate` | `false` |

Jangan mengandalkan `appsettings.json` untuk nilai rahasia. File tersebut hanya berisi default non-rahasia.

### 4.3 Opsi hosting

**A. Platform PaaS (App Service, Render, Railway, Fly.io, dan sejenisnya)**

1. Buat service dari repository atau artefak `publish`.
2. Set seluruh environment variable pada dashboard platform.
3. Set start command ke `dotnet StockMate.Api.dll`.
4. Aktifkan HTTPS.
5. Pastikan health check mengarah ke `/health`.

**B. VPS dengan reverse proxy**

1. Pasang .NET Runtime 8 (atau 10 setelah upgrade) di server.
2. Salin folder `publish` ke server.
3. Jalankan sebagai service (systemd di Linux atau Windows Service).
4. Pasang Nginx/Caddy sebagai reverse proxy TLS.
5. Teruskan header `X-Forwarded-For`/`X-Forwarded-Proto` dan konfigurasikan forwarded headers di API bila diperlukan.

Contoh unit systemd (placeholder path):

```ini
[Unit]
Description=StockMate API
After=network.target

[Service]
WorkingDirectory=/opt/stockmate
ExecStart=/usr/bin/dotnet /opt/stockmate/StockMate.Api.dll
Restart=always
RestartSec=5
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:8080
# Variabel rahasia dimuat dari EnvironmentFile yang tidak di-commit.
EnvironmentFile=/etc/stockmate/stockmate.env

[Install]
WantedBy=multi-user.target
```

**C. Container**

Repository ini **belum menyertakan Dockerfile**. Bila menambahkan:

- Gunakan multi-stage build (`mcr.microsoft.com/dotnet/sdk` → `aspnet`).
- Jalankan sebagai user non-root.
- Jangan menyalin `.env` ke image.
- Expose port sesuai `ASPNETCORE_URLS`.
- Tambahkan health check ke `/health`.

### 4.4 Setelah deploy backend

Isi setelah benar-benar berjalan:

| Item | Nilai |
|---|---|
| Base URL API | `TODO: isi setelah deploy` |
| Health check | `TODO: isi setelah deploy` |
| Swagger (jika diaktifkan) | `TODO: isi setelah deploy` |
| Waktu verifikasi | `TODO: isi setelah deploy` |

## 5. Web React

### 5.1 Build

```bash
cd C:\projects\stockmate\web
npm ci
```

Buat file `.env.production` (jangan commit bila berisi nilai internal):

```text
VITE_API_BASE_URL=https://<domain-api-anda>
```

Lalu:

```bash
npm run lint
npm run build
```

Output ada di `dist/`.

> Nilai `VITE_*` tertanam di bundle saat build. Build ulang setiap kali URL API berubah. Jangan menaruh secret di variabel `VITE_*` karena akan terlihat oleh browser.

### 5.2 Hosting statis

Upload isi `dist/` ke Netlify, Vercel, Cloudflare Pages, GitHub Pages, S3 + CloudFront, Nginx, atau hosting statis lain.

Konfigurasi yang diperlukan:

- **SPA fallback:** semua rute yang tidak dikenal diarahkan ke `index.html` agar React Router bekerja saat refresh.
- **HTTPS** aktif.
- Cache `assets/*` dengan hash panjang; `index.html` tanpa cache agresif.

Contoh Nginx:

```nginx
server {
    listen 443 ssl;
    server_name <domain-web-anda>;

    root /var/www/stockmate-web;
    index index.html;

    location /assets/ {
        try_files $uri =404;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 5.3 CORS

Tambahkan origin web produksi ke backend:

```text
Cors__AllowedOrigins__0=https://<domain-web-anda>
```

Aturan:

- Harus skema + host + port yang persis, tanpa trailing slash.
- Jangan memakai `*` bila memakai credential; konfigurasi saat ini memakai Bearer token, tetapi tetap batasi origin.
- Setelah mengubah CORS, restart API dan uji preflight `OPTIONS`.

### 5.4 Setelah deploy web

| Item | Nilai |
|---|---|
| URL web | `TODO: isi setelah deploy` |
| Waktu verifikasi login | `TODO: isi setelah deploy` |

## 6. Aplikasi Android

### 6.1 Prasyarat

- Flutter SDK stabil.
- Android SDK + build tools.
- JDK yang kompatibel dengan Gradle/AGP.

Di mesin pengembangan saat ini **tidak ada Flutter/Android SDK**, sehingga APK **belum pernah dibangun**.

### 6.2 Menyiapkan platform folder

Folder `android/` belum ada. Dari `C:\projects\stockmate\mobile`:

```bash
flutter create --platforms=android,ios .
```

> Perintah ini dapat menimpa/menambahkan file platform. Tinjau diff dan pertahankan `lib/`, `pubspec.yaml`, serta konfigurasi yang sudah ada. Commit sebelum menjalankan agar perubahan mudah dibandingkan.

Lalu:

```bash
flutter pub get
flutter analyze
```

### 6.3 URL API

Default development: `http://10.0.2.2:5131` (loopback host dari Android emulator).

Untuk build nyata, override saat build:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<domain-api-anda>
```

Jangan mengandalkan default untuk rilis.

### 6.4 Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<domain-api-anda>
```

Output yang diharapkan: `build/app/outputs/flutter-apk/app-release.apk`.

Catatan:

- Untuk Play Store gunakan App Bundle: `flutter build appbundle --release ...`.
- Konfigurasikan signing key produksi; jangan commit keystore/password.
- Uji pada perangkat nyata terhadap API HTTPS.
- Bila API memakai sertifikat internal, konfigurasikan network security dengan benar.

### 6.5 Status build

| Item | Status |
|---|---|
| APK release | **Belum dibangun** — Flutter/Android SDK tidak tersedia di mesin ini |
| `flutter analyze` | **Belum dijalankan** |
| Lokasi APK | `build/app/outputs/flutter-apk/app-release.apk` (setelah build berhasil) |

## 7. Keamanan

- **HTTPS wajib** untuk web, API, dan koneksi database publik.
- **Secret** hanya di secret manager; rotasi `Jwt__SigningKey` akan membatalkan semua token aktif.
- **CORS** dibatasi ke origin yang dikenal.
- **Swagger** dimatikan di produksi kecuali dilindungi autentikasi/jaringan internal.
- **Rate limiting** belum diimplementasikan; pertimbangkan di reverse proxy atau middleware sebelum membuka pendaftaran publik.
- **Password** di-hash BCrypt; password asli tidak pernah disimpan atau di-log.
- **Log** tidak mencatat body request, password, atau token.
- **Database role** aplikasi tidak boleh superuser.
- **Backup** dienkripsi dan disimpan terpisah dari server aplikasi.
- **Dependency** diperbarui berkala; jalankan `dotnet list package --vulnerable` dan `npm audit` sebagai bagian dari proses rilis.

## 8. Operasional

### Log

- API menulis ke console dan `logs/stockmate-<tanggal>.log` (rolling harian, retensi 7 file).
- Pada platform yang memakai filesystem ephemeral, arahkan log ke stdout dan biarkan platform yang mengumpulkan.

### Health check

`GET /health` mengembalikan `200` bila database dapat diakses dan `503` bila tidak. Gunakan endpoint ini untuk readiness/liveness probe.

### Backup dan restore

Lihat [`DATABASE.md`](DATABASE.md) bagian 8. Uji restore, bukan hanya membuat backup.

### Rollback aplikasi

1. Simpan artefak `publish` dan `dist` per rilis (mis. dengan tag versi).
2. Bila rilis gagal, deploy ulang artefak sebelumnya.
3. Perubahan schema harus kompatibel mundur; hindari drop kolom pada rilis yang sama dengan perubahan kode.

## 9. Smoke test pasca-deploy

Jalankan setelah setiap deployment. Ganti placeholder dengan nilai nyata.

```bash
# 1. Health
curl -i https://<domain-api-anda>/health

# 2. Register (gunakan email uji, bukan data pelanggan)
curl -i -X POST https://<domain-api-anda>/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Uji Deploy","email":"uji-deploy@example.com","password":"<password-uji-kuat>"}'

# 3. Login dan simpan token
curl -s -X POST https://<domain-api-anda>/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"uji-deploy@example.com","password":"<password-uji-kuat>"}'

# 4. Kategori
curl -i -X POST https://<domain-api-anda>/api/categories \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Kategori Uji"}'

# 5. Produk
curl -i -X POST https://<domain-api-anda>/api/products \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"sku":"UJI-001","name":"Produk Uji","categoryId":"<uuid-kategori>","price":1000,"minStock":1}'

# 6. Stok masuk
curl -i -X POST https://<domain-api-anda>/api/products/<uuid-produk>/movements \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"type":"IN","quantity":5}'

# 7. Stok keluar melebihi stok harus 409
curl -i -X POST https://<domain-api-anda>/api/products/<uuid-produk>/movements \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"type":"OUT","quantity":99}'
```

Checklist hasil:

- [ ] `/health` → `200`
- [ ] Register → `201`
- [ ] Login → `200` dan token valid
- [ ] Tanpa token ke endpoint terproteksi → `401`
- [ ] Kategori → `201`
- [ ] Produk → `201` dengan `stockQuantity = 0`
- [ ] `IN` → `201`, stok bertambah
- [ ] `OUT` melebihi stok → `409`
- [ ] Web produksi dapat login dan memuat dashboard
- [ ] Tidak ada error CORS di console browser
- [ ] Tidak ada secret terlihat di bundle web atau log

## 10. Status deployment saat ini

| Komponen | Status |
|---|---|
| Database produksi | Belum dibuat — `TODO: isi setelah deploy` |
| API publik | Belum di-deploy — `TODO: isi setelah deploy` |
| Web publik | Belum di-deploy — `TODO: isi setelah deploy` |
| APK | Belum dibangun — toolchain tidak tersedia |
| Smoke test produksi | Belum dijalankan |

Dokumen ini **tidak** menyatakan StockMate siap produksi. Sebelum rilis, selesaikan checklist bagian 2 dan verifikasi setiap langkah secara nyata.
