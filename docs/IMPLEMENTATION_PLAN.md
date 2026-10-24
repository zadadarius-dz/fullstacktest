# StockMate — Implementation Plan

**Diperbarui:** 24 Oktober 2026  
**Status dokumen:** hidup (diperbarui setiap milestone)

## 1. Hasil audit awal (Milestone 0)

### Workspace dan Git

| Item | Kondisi awal |
|---|---|
| Workspace backend | `C:\projects\stockmate` (remote GitHub belum ada) |
| Isi workspace | Hanya `docs/PRD.md` dan dua file prompt. **Tidak ada** solution, `.csproj`, `Program.cs`, atau kode API. |
| Git | Repository sudah diinisialisasi, branch `master`, **belum ada commit** sama sekali. |
| `.gitignore` | Belum ada. |
| Web / mobile | Folder `C:\Projects\stockmate-web` dan `C:\Projects\stockmate-mobile` belum ada. |

Karena tidak ada scaffold `StockMate.Api` atau `WeatherForecast` yang perlu dipertahankan, backend dibuat baru dari nol. Tidak ada pekerjaan pengguna yang ditimpa.

### Tooling

| Tool | Versi / status |
|---|---|
| .NET SDK | **8.0.426** (satu-satunya SDK terpasang) |
| .NET runtime | 8.0.32 (ASP.NET Core + Windows Desktop) |
| .NET 10 SDK | **Tidak terpasang** |
| Node.js | v24.18.0 |
| npm | 11.16.0 |
| Flutter / Dart | **3.47.8 stable / Dart 3.13.7** (portable di `%LOCALAPPDATA%\flutter`) |
| Android SDK | **36.1.0** di `%LOCALAPPDATA%\Android\Sdk`; build-tools 36.0.0/36.1.0/37.0.0; JDK 17 dari Android Studio |
| PostgreSQL | **18.6**, service `postgresql-x64-18` **running** pada port 5432 |
| `psql` | Tersedia di `C:\Program Files\PostgreSQL\18\bin\psql.exe`, tidak ada di `PATH` |
| Docker | Tidak tersedia |
| Git | Tersedia, `user.name`/`user.email` sudah dikonfigurasi |

### Koneksi PostgreSQL

- Autentikasi instance utama memakai `scram-sha-256` untuk semua koneksi lokal.
- Koneksi tanpa password ditolak: `fe_sendauth: no password supplied`.
- **Password tidak diminta dan tidak akan disimpan di repository.** Pengguna harus mengisi connection string melalui environment variable.
- Untuk verifikasi integrasi nyata tanpa menyentuh instance utama, integration test memakai cluster PostgreSQL sementara yang dibuat dengan `initdb` (trust auth, port terpisah) bila tersedia. Hasilnya dilaporkan terpisah dari instance utama.
- Pada 24 Oktober 2026, database `stockmate` dan role `stockmate_app` dibuat di instance utama melalui skrip interaktif; schema `001_initial_schema.sql` berhasil dijalankan dan `/health` mengembalikan `Healthy`. Password hanya dimasukkan di jendela skrip dan tidak disimpan di repository.

### Keputusan teknologi

| Keputusan | Alasan |
|---|---|
| Target `net8.0` (sementara) | Hanya SDK 8.0.426 tersedia dan aturan prompt melarang klaim .NET 10. Semua paket memakai versi 8.x yang kompatibel. **Wajib ditinjau sebelum deployment/rilis**; upgrade ke `net10.0` didokumentasikan di README. |
| Satu proyek `StockMate.Api` modular | Sesuai PRD; folder `Controllers`, `DTOs`, `Models`, `Services`, `Repositories`, `Data`, `Middleware`. |
| Dapper + Npgsql | Sesuai PRD, SQL berparameter, transaksi eksplisit untuk stok. |
| BCrypt.Net-Next | Hash password BCrypt. |
| JWT Bearer | Signing key dari environment; di Development boleh memakai key ephemeral in-memory agar developer bisa langsung menjalankan API tanpa menaruh secret di repo. Di Production key wajib. |
| Serilog | Console + rolling file, request logging tanpa body/credential. |
| React + Vite (JavaScript) | Sesuai PRD; mengurangi beban setup. |
| Flutter | Flutter 3.47.8 + Android SDK 36; `flutter analyze`, `flutter test`, dan build APK dijalankan pada 24 Oktober 2026. |

## 2. Milestone dan status

| # | Milestone | Status |
|---|---|---|
| 0 | Audit + rencana | ✅ Selesai |
| 1 | Backend ASP.NET Core, konfigurasi PostgreSQL, schema SQL, logging, error handling, Swagger, CORS | ✅ Selesai |
| 2 | Auth (register/login/JWT/BCrypt), CRUD kategori & produk | ✅ Selesai |
| 3 | Stock movements atomik + dashboard + integration test | ✅ Selesai |
| 4 | Build/test backend dan smoke test API | ✅ Selesai — 9/9 test lulus |
| 5 | React web (`stockmate-web`) | ✅ Selesai — lint bersih, build berhasil |
| 6 | Flutter mobile (`mobile/`) | ✅ Selesai — analyze bersih, 5/5 test, APK 50,0 MB terpasang & berjalan di HP Android 14 |
| 7 | Deployment preparation + dokumentasi final | ✅ Dokumentasi selesai; **deployment belum dilakukan** |

### Hasil verifikasi akhir (24 Oktober 2026)

**Struktur akhir:** monorepo `https://github.com/zadadarius-dz/fullstacktest.git` dengan backend di root, web di `web/`, dan mobile di `mobile/`.

| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Build backend | `dotnet build StockMate.sln` | Berhasil, **0 warning / 0 error**, 7,76 detik |
| Integration test | `dotnet test StockMate.sln --no-build` | **9 lulus**, 0 gagal, 0 skip, 12,4773 detik |
| Web lint | `npm run lint` | Bersih |
| Web build | `npm run build` | Berhasil, 53 modul, 905 ms |
| Mobile analyze | `flutter analyze` | **No issues found** |
| Mobile test | `flutter test` | **5/5 lulus** |
| Mobile APK | `flutter build apk --release --dart-define=API_BASE_URL=http://127.0.0.1:5131` | Berhasil, **50,0 MB**, 123,9 detik (build kedua) |
| Mobile runtime | `adb install` + `adb shell am start` | Terpasang dan berjalan di 2410FPCC5G Android 14; login & dashboard `200` |
| Deployment | – | Belum dilakukan; tidak ada URL publik |

Detail lengkap ada di [`TESTING.md`](TESTING.md).

## 3. Rancangan backend

### Struktur

```text
StockMate.sln
StockMate.Api/
  Controllers/      Auth, Categories, Products, StockMovements, Dashboard, Health
  DTOs/             Request/response terpisah dari model database
  Models/           User, Category, Product, StockMovement
  Repositories/     Dapper + Npgsql, semua query berparameter
  Services/         Aturan bisnis, JWT, validasi, current user
  Data/             Connection factory, Migrations/001_initial_schema.sql
  Middleware/       Global exception handler (ProblemDetails)
  Program.cs
  appsettings.json
StockMate.Api.Tests/  Unit + integration tests
```

### Aturan bisnis kunci

- `user_id` **selalu** dari klaim JWT (`sub`), tidak pernah dari body/query.
- Kategori: nama 2–80 karakter, unik per user case-insensitive; tidak bisa dihapus jika dipakai produk (`409`).
- Produk: SKU di-trim + uppercase, unik per user; stok awal selalu 0; `PUT` tidak menyentuh `stock_quantity`; `DELETE` = soft delete (`is_active = false`).
- Movement: `IN`/`OUT`, quantity > 0, `SELECT ... FOR UPDATE` di dalam transaksi, tolak `OUT` melebihi stok (`409`), insert riwayat + update stok commit bersama.
- Pagination: default 10/20, `pageSize` maksimum 100.
- Error: `ProblemDetails` konsisten; detail internal hanya masuk log.
- CORS: origin eksplisit dari konfigurasi, default `http://localhost:5173` dan `http://127.0.0.1:5173`.

### Endpoint (ringkas)

`POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`, CRUD `/api/categories`, CRUD `/api/products`, `POST|GET /api/products/{id}/movements`, `GET /api/stock-movements`, `GET /api/dashboard/summary`, `GET /health`.

## 4. Blocker dan tindakan manual

| Blocker | Dampak | Tindakan |
|---|---|---|
| .NET 10 SDK tidak terpasang | Target sementara `net8.0` | Pasang .NET 10 SDK, ubah `TargetFramework` + paket ke 10.x, restore/build/test ulang sebelum rilis. |
| Password PostgreSQL instance utama tidak tersedia (dan tidak boleh diminta) | API tidak bisa memakai DB 5432 tanpa konfigurasi pengguna | Pengguna membuat database + mengisi `ConnectionStrings__DefaultConnection` di environment. Panduan ada di README/DATABASE.md. |
| Flutter/Android SDK tidak terpasang | Sudah teratasi: Flutter 3.47.8 + Android SDK 36 terpasang | Analyze, test, dan APK sudah dijalankan; sisa pekerjaan adalah uji manual alur lengkap. |
| Tidak ada akses provider hosting | Tidak ada deployment | Monorepo sudah di-push ke GitHub; deployment masih ditandai `TODO: isi setelah deploy`. |

## 5. Definition of Done (checklist proyek)

- [x] `dotnet build` bersih (0 warning / 0 error)
- [x] Schema SQL dapat dijalankan ulang (idempoten, diuji pada DB test)
- [x] Auth + CRUD + movement + dashboard berfungsi dan teruji (9 test)
- [x] Isolasi data antar user teruji
- [x] Stok tidak pernah negatif (row lock + constraint, uji 20 request paralel)
- [x] Swagger berisi endpoint StockMate (smoke test manual)
- [x] Web build bersih (lint + Vite build)
- [ ] Mobile dianalisis/di-build — **belum**, Flutter/Android SDK tidak tersedia
- [x] README + docs API/DB/deployment/testing lengkap, tanpa klaim palsu
- [ ] Deployment produksi — **belum**, tidak ada provider/credential

## 6. Daftar dokumen akhir

| Dokumen | Isi |
|---|---|
| `README.md` | Setup backend, environment, database, build/test, arsitektur, troubleshooting |
| `.env.example` | Placeholder konfigurasi (tanpa nilai rahasia) |
| `docs/PRD.md` | Kebutuhan produk (sumber) |
| `docs/IMPLEMENTATION_PLAN.md` | Audit, keputusan, milestone, blocker |
| `docs/API.md` | Referensi endpoint, payload, status, contoh curl |
| `docs/DATABASE.md` | ERD, tabel, constraint, index, transaksi, backup |
| `docs/DEPLOYMENT.md` | Langkah deploy backend/DB/web/mobile, checklist, smoke test |
| `docs/TESTING.md` | Hasil build/test aktual, matriks test, cara menjalankan |
| `web/README.md` | Setup, script, rute, environment web |
| `mobile/README.md` | Setup Flutter, secure storage, URL API, status build |

## 7. Pekerjaan lanjutan (di luar scope MVP)

- Upgrade target ke `net10.0` dan paket 10.x, lalu build/test ulang.
- Pasang Flutter + Android SDK, jalankan `flutter analyze`, build APK, uji di perangkat.
- Deployment nyata ke provider, isi placeholder URL di dokumen.
- Rate limiting dan hardening tambahan sebelum pendaftaran publik.
- Migration berversi, CI/CD, dan pemantauan produksi.
