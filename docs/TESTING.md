# StockMate — Testing

**Tanggal verifikasi terakhir:** 24 Oktober 2026  
**Lingkungan:** Windows, .NET SDK 8.0.426, PostgreSQL 18.6, Node.js 24.18.0  
**Status ringkas:** backend build bersih, **9/9 integration test lulus**, web lint bersih dan build berhasil. Mobile **belum diverifikasi** karena Flutter tidak terpasang.

Dokumen ini hanya memuat hasil yang benar-benar dijalankan. Bagian yang belum diuji ditandai eksplisit.

## 1. Ringkasan hasil aktual

| Area | Perintah | Hasil |
|---|---|---|
| Backend build | `dotnet build StockMate.sln` | **Berhasil**, 0 warning, 0 error, 7,76 detik |
| Backend test | `dotnet test StockMate.sln --no-build` | **9 lulus, 0 gagal, 0 skip**, 12,4773 detik |
| Web lint | `npm run lint` (oxlint) | **Bersih**, tanpa warning |
| Web build | `npm run build` (Vite 8.3.5) | **Berhasil**, 53 modul, 905 ms |
| Web output | `dist/` | JS 303,05 kB (gzip 92,14 kB); CSS 14,26 kB (gzip 3,72 kB); HTML 0,65 kB |
| Mobile analyze | `flutter analyze` | **Tidak dijalankan** — Flutter tidak terpasang |
| Mobile build | `flutter build apk` | **Tidak dijalankan** — Android SDK tidak terpasang |
| Deployment | – | **Belum dilakukan** |

Tidak ada hasil test atau build yang disimulasikan.

## 2. Lingkungan pengujian

| Komponen | Versi |
|---|---|
| OS | Windows |
| .NET SDK | 8.0.426 |
| .NET runtime | 8.0.32 |
| xUnit VSTest Adapter | 2.5.3.1 |
| PostgreSQL | 18.6 |
| Node.js | 24.18.0 |
| npm | 11.16.0 |
| Vite | 8.3.5 |
| React | 19.3.1 |
| Flutter / Dart | Tidak terpasang |

### Database pengujian

Integration test **tidak** memakai instance PostgreSQL utama pengguna (port 5432, autentikasi `scram-sha-256`) karena password tidak tersedia dan tidak diminta. Verifikasi memakai cluster PostgreSQL sementara yang dibuat dengan `initdb`:

- Host: `127.0.0.1`
- Port: `55432`
- Database: `stockmate_test`
- Autentikasi: trust (hanya lokal, sementara)
- Status: cluster sementara, bukan bagian dari instalasi pengguna

Connection string ini hanya dipakai di shell saat pengujian dan tidak disimpan di repository.

## 3. Cara menjalankan test backend

### 3.1 Prasyarat

- .NET SDK sesuai target proyek.
- Database PostgreSQL khusus test yang dapat ditulis.
- Variabel `STOCKMATE_TEST_DATABASE`.

### 3.2 Perintah

```powershell
dotnet build StockMate.sln

$env:STOCKMATE_TEST_DATABASE = 'Host=localhost;Port=5432;Database=stockmate_test;Username=stockmate_app;Password=<password-anda>'
dotnet test StockMate.sln --no-build --logger "console;verbosity=normal"
```

Bash:

```bash
export STOCKMATE_TEST_DATABASE='Host=localhost;Port=5432;Database=stockmate_test;Username=stockmate_app;Password=<password-anda>'
dotnet test StockMate.sln --logger "console;verbosity=normal"
```

### 3.3 Perilaku bila variabel tidak diisi

Test integration akan **skip** dengan pesan yang menjelaskan cara mengisi `STOCKMATE_TEST_DATABASE`. Ini disengaja agar `dotnet test` tidak gagal pada mesin tanpa database.

### 3.4 Peringatan

- Jangan arahkan ke database produksi atau database kerja utama. Test membuat dan membersihkan data.
- Test factory mengaktifkan auto-migrate pada database test.
- Test dapat berjalan paralel; uji konkurensi membuat data sendiri.

## 4. Matriks test backend (9 test)

Semua test berada di `StockMate.Api.Tests/StockMateApiTests.cs` dan memakai `WebApplicationFactory` sehingga request melewati pipeline HTTP nyata (routing, autentikasi, model validation, middleware error, Dapper, PostgreSQL).

| # | Test | Yang diverifikasi |
|---|---|---|
| 1 | `Auth_Register_Login_And_Protected_Endpoints_Work` | Register `201`, login `200`, token dapat mengakses endpoint terproteksi, respons tidak memuat `passwordHash`. |
| 2 | `Auth_Rejects_Invalid_Input` | Email tidak valid, password terlalu pendek, dan field wajib kosong menghasilkan `400` dengan `ProblemDetails`. |
| 3 | `Categories_Crud_And_Duplicate_Name_Conflict` | Create, read, update, list kategori; nama duplikat (beda kapitalisasi) menghasilkan `409`. |
| 4 | `Category_In_Use_Cannot_Be_Deleted` | Kategori yang dipakai produk tidak dapat dihapus (`409`); kategori tanpa produk dapat dihapus (`204`). |
| 5 | `Products_Start_At_Zero_Update_Keeps_Stock_And_Delete_Is_Soft` | Produk baru `stockQuantity = 0`; `PUT` tidak mengubah stok; `DELETE` menyembunyikan produk dari daftar tanpa menghapus riwayat. |
| 6 | `Movements_Reject_NonPositive_Quantity_And_Oversell` | Quantity `0`/negatif ditolak `400`; `OUT` melebihi stok ditolak `409`; stok tidak berubah setelah penolakan. |
| 7 | `User_Cannot_Access_Another_Users_Data` | Pengguna B tidak dapat membaca/mengubah produk atau kategori pengguna A; respons `404`. |
| 8 | `Dashboard_Reflects_Inventory` | Jumlah produk aktif, kategori, total unit, dan daftar stok menipis sesuai data. |
| 9 | `Concurrent_Out_Requests_Never_Oversell` | 20 request `OUT` paralel terhadap stok 10 → tepat 10 sukses, 10 `409`, stok akhir 0. |

### 4.1 Detail uji konkurensi

Skenario:

1. Buat produk dengan stok awal 0.
2. Catat `IN` sebesar 10.
3. Kirim 20 request `OUT` quantity 1 secara bersamaan.
4. Periksa status dan stok akhir.

Hasil aktual:

| Metrik | Nilai |
|---|---|
| Request `OUT` | 20 |
| `201 Created` | 10 |
| `409 Conflict` | 10 |
| Stok akhir | 0 |
| Movement `OUT` tercatat | 10 |
| Stok negatif | Tidak ada |

Ini membuktikan `SELECT ... FOR UPDATE` + transaksi berhasil mencegah oversell.

### 4.2 Cakupan yang belum diuji otomatis

- Rate limiting (belum diimplementasikan).
- Refresh token/rotasi token (tidak ada di scope).
- Beban tinggi di luar 20 request paralel.
- Failover database.
- Endpoint `/health` diuji manual (smoke test), bukan di integration test.
- Perilaku setelah upgrade ke .NET 10.

## 5. Smoke test API manual

Selain integration test, dilakukan smoke test terhadap API yang berjalan di `http://127.0.0.1:5131` dengan database sementara.

| Langkah | Hasil |
|---|---|
| `GET /health` | `200`, database sehat |
| Swagger UI dan `swagger.json` | Dapat diakses, memuat endpoint StockMate |
| `POST /api/auth/register` | `201` |
| `POST /api/categories` | `201` |
| `POST /api/products` | `201`, stok awal 0 |
| `POST .../movements` `IN 10` | `201`, stok 10 |
| `POST .../movements` `OUT 3` | `201`, stok 7 |
| `OUT` melebihi stok | `409` |
| `GET /api/products/{id}` | Stok 7 |
| `GET /api/dashboard/summary` | Angka sesuai |
| `GET .../movements` | Riwayat IN dan OUT benar |
| Request tanpa token | `401` |

JWT key untuk smoke test hanya berada di shell dan tidak disimpan di repository.

## 6. Pengujian web

### 6.1 Perintah dan hasil

```powershell
cd C:\Projects\stockmate-web
npm run lint
npm run build
```

Hasil:

- `oxlint`: tidak ada warning/error.
- `vite build`: berhasil.
- `53 modules transformed`.
- `dist/assets/index-Dbv9wgHn.css` 14,26 kB (gzip 3,72 kB).
- `dist/assets/index-jApJXHjJ.js` 303,05 kB (gzip 92,14 kB).
- `dist/index.html` 0,65 kB (gzip 0,40 kB).
- Waktu build 905 ms.

### 6.2 Yang belum diuji

- Unit test komponen (belum ada).
- E2E browser otomatis (Playwright/Cypress belum dipasang).
- Uji manual lintas browser dan perangkat nyata.
- Uji aksesibilitas otomatis.
- Uji performa Lighthouse.
- Deployment produksi.

### 6.3 Checklist manual yang disarankan

Jalankan dengan backend aktif dan database berisi data uji:

- [ ] Register akun baru dari halaman web.
- [ ] Login, refresh halaman, sesi tetap aktif.
- [ ] Logout menghapus token dan mengarahkan ke login.
- [ ] Akses rute terproteksi tanpa token → diarahkan ke login.
- [ ] CRUD kategori, termasuk pesan duplikat.
- [ ] Hapus kategori yang masih dipakai → pesan `409`.
- [ ] Create produk → stok 0.
- [ ] Edit produk → stok tidak berubah.
- [ ] Pencarian, filter kategori, filter stok menipis, pagination.
- [ ] Catat `IN` dan `OUT`; stok dan riwayat langsung diperbarui.
- [ ] `OUT` melebihi stok → pesan error yang jelas.
- [ ] Soft delete produk → hilang dari daftar, riwayat tetap ada.
- [ ] Dashboard menampilkan angka yang sesuai.
- [ ] Tampilan responsif pada lebar 360 px, 768 px, dan desktop.
- [ ] State loading, empty, error, dan sukses terlihat.

## 7. Pengujian mobile

### 7.1 Status

**Belum diverifikasi.** Flutter/Dart tidak terpasang di mesin ini, sehingga perintah berikut belum pernah dijalankan:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://<domain-api-anda>
```

Tidak ada klaim bahwa kode mobile berhasil dikompilasi atau APK tersedia.

### 7.2 Langkah verifikasi yang harus dilakukan

1. Pasang Flutter SDK stabil dan Android SDK.
2. Dari `C:\Projects\stockmate-mobile`, jalankan `flutter create --platforms=android,ios .` (tinjau diff).
3. `flutter pub get`.
4. `flutter analyze` — perbaiki semua error/warning.
5. `flutter test` bila test ditambahkan.
6. Jalankan di emulator/perangkat dengan backend aktif.
7. `flutter build apk --release --dart-define=API_BASE_URL=...`.
8. Uji APK pada perangkat nyata.

### 7.3 Checklist manual mobile

- [ ] Register dan login; token tersimpan aman.
- [ ] Restart aplikasi → sesi dipulihkan dari secure storage.
- [ ] Dashboard menampilkan ringkasan.
- [ ] Daftar produk, pencarian, filter kategori, filter stok menipis.
- [ ] Buat kategori cepat dari form produk.
- [ ] Create produk → stok 0.
- [ ] Edit produk → stok tidak berubah.
- [ ] Catat `IN`/`OUT`; stok dan riwayat diperbarui.
- [ ] `OUT` melebihi stok → pesan `409`.
- [ ] Soft delete produk.
- [ ] Riwayat seluruh produk dan per produk.
- [ ] Logout.
- [ ] Token kedaluwarsa → kembali ke login.
- [ ] Tampilan pada layar kecil dan tablet.

## 8. Checklist Definition of Done

| Kriteria | Status |
|---|---|
| `dotnet build` bersih | ✅ 0 warning / 0 error |
| Schema SQL dapat dijalankan ulang | ✅ diverifikasi idempoten pada DB test |
| Auth + CRUD + movement + dashboard teruji | ✅ 9 integration test |
| Isolasi data antar user teruji | ✅ test #7 |
| Stok tidak pernah negatif | ✅ constraint + test #6 dan #9 |
| Swagger memuat endpoint StockMate | ✅ smoke test manual |
| Web build bersih | ✅ lint + build |
| Mobile dianalisis/di-build | ⛔ belum — toolchain tidak tersedia |
| Dokumentasi lengkap tanpa klaim palsu | ✅ README + API + DATABASE + DEPLOYMENT + TESTING |
| Deployment produksi | ⛔ belum dilakukan |

## 9. Reproduksi hasil

Untuk mengulang verifikasi backend dari kondisi bersih:

```powershell
# 1. Build
cd C:\projects\stockmate
dotnet restore StockMate.sln
dotnet build StockMate.sln

# 2. Siapkan database test (contoh; sesuaikan dengan lingkungan Anda)
#    Buat database kosong bernama stockmate_test terlebih dahulu.

# 3. Test
$env:STOCKMATE_TEST_DATABASE = 'Host=localhost;Port=5432;Database=stockmate_test;Username=stockmate_app;Password=<password-anda>'
dotnet test StockMate.sln --no-build --logger "console;verbosity=normal"

# 4. Web
cd C:\Projects\stockmate-web
npm ci
npm run lint
npm run build
```

Hasil yang diharapkan: build tanpa warning, seluruh test lulus, lint bersih, dan folder `dist/` terbentuk.

Jika hasil berbeda, periksa versi SDK, ketersediaan PostgreSQL, dan isi `STOCKMATE_TEST_DATABASE`. Jangan menganggap hasil lama berlaku untuk perubahan kode baru; jalankan ulang.
