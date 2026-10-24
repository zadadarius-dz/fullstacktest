# Product Requirements Document (PRD) — StockMate

**Versi:** 1.0  
**Status:** Siap diimplementasikan  
**Tanggal:** 24 Oktober 2026  
**Target pengerjaan:** 7 hari  
**Produk:** StockMate — Simple Inventory Management System

## 1. Ringkasan Produk

StockMate adalah aplikasi inventaris sederhana untuk pemilik usaha kecil yang ingin mencatat produk, mengatur kategori, memperbarui stok melalui transaksi masuk/keluar, dan melihat ringkasan persediaan. Produk terdiri atas REST API, aplikasi web, dan aplikasi Android yang menggunakan backend serta database yang sama.

Prinsip produk: scope kecil, alur kerja nyata, data konsisten, keamanan dasar diterapkan, dan aplikasi dapat dijalankan/deploy dengan instruksi yang jelas.

## 2. Masalah yang Diselesaikan

Pencatatan stok manual mudah menimbulkan kesalahan, stok dapat menjadi negatif, dan riwayat perubahan stok sulit ditelusuri. StockMate menyediakan satu sumber data untuk produk dan pergerakan stok.

## 3. Tujuan dan Batasan

### 3.1 Tujuan

1. Pengguna dapat register dan login dengan JWT.
2. Pengguna dapat melakukan CRUD kategori dan produk.
3. Produk harus memiliki kategori dan SKU yang unik per pengguna.
4. Pengguna dapat mencatat stok masuk dan stok keluar.
5. Sistem menolak stok keluar yang melebihi stok tersedia.
6. Setiap transaksi stok tercatat dan tersimpan bersama perubahan jumlah stok secara atomik.
7. Aplikasi web React dan mobile Flutter menggunakan API yang sama.
8. Backend dan web dapat di-deploy; APK Android release dapat dibuat.
9. Setiap repository memiliki README yang cukup untuk setup dan evaluasi.

### 3.2 Bukan bagian MVP (Non-goals)

- Multi-gudang, supplier/purchase order, barcode scanner, invoice, ekspor PDF/Excel, notifikasi push, pembayaran, approval workflow, dan role admin yang kompleks.
- Integrasi dengan sistem POS atau akuntansi eksternal.
- Real-time WebSocket. Frontend mengambil data terbaru setelah operasi berhasil atau saat halaman dimuat.
- CRUD edit/hapus untuk riwayat pergerakan stok; riwayat adalah catatan audit.

## 4. Pengguna dan Hak Akses

MVP menggunakan model satu pemilik data per akun. Pengguna yang telah login hanya boleh melihat dan mengubah kategori, produk, dan pergerakan stok miliknya sendiri. Tidak ada role admin terpisah.

**Aturan keamanan utama:** setiap query yang membaca atau mengubah kategori/produk harus dibatasi oleh `user_id` dari token tervalidasi. Jangan memercayai `user_id` yang dikirim melalui request body.

## 5. Platform dan Teknologi

| Lapisan | Teknologi |
|---|---|
| Backend | ASP.NET Core Web API, C# |
| Framework target yang direkomendasikan | .NET 10 LTS untuk proyek baru |
| Database | PostgreSQL 18.x |
| SQL access | Dapper + Npgsql dengan query berparameter |
| Auth | JWT Bearer; BCrypt untuk password hash |
| Logging | Serilog |
| API documentation | Swagger/OpenAPI |
| Web | React + Vite, JavaScript, React Router, Context API, Fetch API |
| Mobile | Flutter, Provider, `http`, `flutter_secure_storage` untuk token |
| Git | Conventional Commits; tiga repository terpisah |

**Catatan versi:** komputer saat ini memiliki SDK .NET 8.0.426, tetapi .NET 8 dijadwalkan berakhir dukungan pada 10 November 2026; .NET 10 LTS didukung sampai 14 November 2028. Karena proyek masih berupa scaffold awal, instal SDK .NET 10 sebelum implementasi fitur dan gunakan `net10.0`. Sumber resmi: https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core. Jangan menggunakan .NET 11 RC untuk proyek ini karena versi prarilis tidak diperlukan.

Jika ada kendala instalasi SDK yang tidak dapat diselesaikan dalam waktu tes, catat trade-off tersebut dan gunakan target framework yang benar-benar terinstal; jangan mencampur target framework dan versi paket tanpa build/test.

## 6. Fitur dan Kriteria Penerimaan

### 6.1 Autentikasi

- Register menerima nama, email, dan password.
- Email dinormalisasi dan unik tanpa membedakan kapitalisasi.
- Password disimpan hanya sebagai hash BCrypt, tidak pernah sebagai teks biasa.
- Login mengembalikan access token JWT dan informasi pengguna non-sensitif.
- Endpoint terproteksi merespons `401 Unauthorized` untuk token yang tidak valid/kedaluwarsa.
- JWT signing key berasal dari environment variable/secret manager, bukan nilai rahasia di source control.

### 6.2 Kategori

CRUD lengkap: create, list, detail, update, delete.

- Nama kategori wajib, panjang 2–80 karakter.
- Nama kategori unik per pengguna (case-insensitive).
- Pengguna tidak dapat membaca atau memodifikasi kategori milik pengguna lain.
- Kategori tidak dapat dihapus jika masih dipakai produk; API mengembalikan `409 Conflict` dengan pesan yang aman dan jelas.

### 6.3 Produk

CRUD lengkap: create, list, detail, update, delete.

Field utama: SKU, nama, kategori, deskripsi opsional, harga, stok saat ini, batas stok minimum, status aktif.

- SKU wajib dan unik per pengguna.
- Nama wajib (2–160 karakter); deskripsi opsional (maks. 500 karakter).
- Harga harus `>= 0`; `min_stock >= 0`.
- Produk harus menggunakan kategori yang dimiliki pengguna yang sedang login.
- Stok awal saat produk dibuat adalah `0`. Perubahan stok berikutnya hanya melalui endpoint pergerakan stok, bukan form edit produk.
- `PUT` produk hanya mengubah data produk yang dapat diedit, bukan `stock_quantity`.
- `DELETE` produk menerapkan soft delete (`is_active = false`) agar riwayat transaksi tetap utuh. Daftar produk default hanya menampilkan produk aktif.
- Daftar produk mendukung pagination serta pencarian sederhana berdasarkan nama/SKU dan filter kategori/low-stock.

### 6.4 Pergerakan Stok

Jenis transaksi: `IN` (stok masuk) dan `OUT` (stok keluar). Riwayat bersifat append-only.

- `quantity` wajib bilangan bulat positif.
- Setiap pergerakan menyimpan produk, tipe, jumlah, stok sebelum, stok sesudah, catatan opsional, pengguna pencatat, dan waktu.
- `OUT` yang melebihi stok tersedia ditolak dengan `409 Conflict`; stok tidak pernah menjadi negatif.
- Update stok produk dan insert riwayat dilakukan dalam satu transaksi database. Gunakan row lock (`SELECT ... FOR UPDATE`) atau strategi transaksi setara untuk mencegah race condition.
- `user_id` pada pencatatan berasal dari klaim token, tidak dari request body.
- Tidak ada endpoint update/delete untuk riwayat pergerakan.

### 6.5 Dashboard

Endpoint ringkasan menampilkan:
- jumlah produk aktif;
- jumlah kategori;
- total unit stok produk aktif;
- jumlah produk yang stoknya `<= min_stock`;
- daftar singkat produk yang stoknya menipis (opsional bila waktu cukup).

### 6.6 Feedback dan UX

Web dan mobile harus menampilkan loading state, empty state, pesan sukses, dan pesan error yang bisa dimengerti. Form memiliki validasi input dasar dan mencegah pengiriman berulang saat request sedang berlangsung. Layout web setidaknya responsif untuk desktop dan tablet.

## 7. Model Data

### 7.1 `users`

- `id UUID PRIMARY KEY`
- `name VARCHAR(100) NOT NULL`
- `email VARCHAR(255) NOT NULL` — email dinormalisasi ke lowercase dan unik
- `password_hash TEXT NOT NULL`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 7.2 `categories`

- `id UUID PRIMARY KEY`
- `user_id UUID NOT NULL REFERENCES users(id)`
- `name VARCHAR(80) NOT NULL`
- `created_at`, `updated_at` menggunakan `TIMESTAMPTZ`
- Unique index case-insensitive untuk `(user_id, lower(name))`

### 7.3 `products`

- `id UUID PRIMARY KEY`
- `user_id UUID NOT NULL REFERENCES users(id)`
- `category_id UUID NOT NULL REFERENCES categories(id)`
- `sku VARCHAR(64) NOT NULL`
- `name VARCHAR(160) NOT NULL`
- `description VARCHAR(500) NULL`
- `price NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (price >= 0)`
- `stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0)`
- `min_stock INTEGER NOT NULL DEFAULT 0 CHECK (min_stock >= 0)`
- `is_active BOOLEAN NOT NULL DEFAULT TRUE`
- `created_at`, `updated_at` menggunakan `TIMESTAMPTZ`
- Unique constraint `(user_id, sku)`
- Index yang wajar untuk `user_id`, `category_id`, `name`, dan `sku` jika dibutuhkan query.

### 7.4 `stock_movements`

- `id UUID PRIMARY KEY`
- `product_id UUID NOT NULL REFERENCES products(id)`
- `created_by_user_id UUID NOT NULL REFERENCES users(id)`
- `type VARCHAR(3) NOT NULL CHECK (type IN ('IN','OUT'))`
- `quantity INTEGER NOT NULL CHECK (quantity > 0)`
- `stock_before INTEGER NOT NULL CHECK (stock_before >= 0)`
- `stock_after INTEGER NOT NULL CHECK (stock_after >= 0)`
- `note VARCHAR(300) NULL`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- Index `(product_id, created_at DESC)`.

Semua ID dibuat di server (misalnya `Guid.NewGuid()`) atau dengan default PostgreSQL yang konsisten. Gunakan foreign key, check constraint, dan parameter SQL. Jangan menyusun query dengan menggabungkan input pengguna menjadi string SQL.

## 8. Kontrak REST API

Semua route menggunakan prefix `/api`. Route selain register/login memerlukan `Authorization: Bearer <token>`.

### Auth

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/api/auth/register` | Membuat akun |
| POST | `/api/auth/login` | Login dan menerima JWT |

### Kategori

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/api/categories` | Daftar kategori pengguna |
| POST | `/api/categories` | Membuat kategori |
| GET | `/api/categories/{id}` | Detail kategori |
| PUT | `/api/categories/{id}` | Memperbarui kategori |
| DELETE | `/api/categories/{id}` | Hapus jika belum digunakan produk |

### Produk

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/api/products?page=1&pageSize=10&search=&categoryId=&lowStock=` | Daftar/pencarian/pagination |
| POST | `/api/products` | Membuat produk; stok dimulai dari 0 |
| GET | `/api/products/{id}` | Detail produk aktif milik pengguna |
| PUT | `/api/products/{id}` | Memperbarui field yang dapat diedit |
| DELETE | `/api/products/{id}` | Soft delete |

### Pergerakan stok

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/api/products/{id}/movements` | Mencatat `IN` atau `OUT` |
| GET | `/api/products/{id}/movements?page=1&pageSize=20` | Riwayat produk |
| GET | `/api/stock-movements?page=1&pageSize=20` | Riwayat semua produk pengguna |

Contoh request pencatatan stok:

```json
{
  "type": "IN",
  "quantity": 10,
  "note": "Stok awal dari pemasok"
}
```

### Dashboard

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/api/dashboard/summary` | Ringkasan inventaris pengguna |

### Format response dan status

- Sukses: JSON dengan nama properti camelCase; create dapat memakai `201 Created`.
- Input tidak valid: `400 Bad Request` dengan detail validasi yang aman.
- Belum login/token invalid: `401 Unauthorized`.
- Resource tidak ada atau bukan milik pengguna: `404 Not Found`.
- Konflik bisnis (SKU duplikat, kategori sedang digunakan, stok keluar terlalu banyak): `409 Conflict`.
- Error tak terduga: `500 Internal Server Error` tanpa stack trace kepada client.
- Gunakan `ProblemDetails` atau struktur error konsisten pada semua endpoint.

## 9. Struktur Repository dan Arsitektur

Gunakan tiga repository GitHub yang terpisah:

1. `stockmate-api` — backend ASP.NET Core + SQL scripts.
2. `stockmate-web` — frontend React.
3. `stockmate-mobile` — aplikasi Flutter.

Nama folder lokal backend yang sudah dibuat boleh tetap `StockMate`; yang penting repository remote dan README jelas.

### Backend — satu proyek modular

```text
StockMate.Api/
├── Controllers/
├── DTOs/
├── Models/
├── Services/
├── Repositories/
├── Data/
│   ├── DbConnectionFactory.cs
│   └── Migrations/
│       └── 001_initial_schema.sql
├── Middleware/
├── Properties/
├── Program.cs
├── appsettings.json
└── README.md
```

Tanggung jawab: Controllers menangani HTTP, Services menerapkan aturan bisnis, Repositories berisi SQL/Dapper, DTOs membatasi data request/response, Middleware menangani error global. Jangan menaruh semua logika dalam controller.

### Web

```text
src/
├── api/          # fetch wrapper dan endpoint functions
├── components/
├── context/      # auth context
├── layouts/
├── pages/        # Login, Register, Dashboard, Products, Categories, Movements
├── routes/
├── utils/
└── main.jsx
```

### Mobile

```text
lib/
├── core/         # config API, error handling, shared widgets
├── models/
├── providers/
├── services/     # HTTP client dan auth token
├── screens/     # Login, Register, Dashboard, Products, ProductForm, Movements
├── widgets/
└── main.dart
```

## 10. Keamanan, Validasi, dan Logging

- Hash password menggunakan BCrypt; jangan simpan atau log password/token.
- JWT signing key, connection string produksi, dan URL environment disimpan dalam environment variables/secret manager.
- Query SQL menggunakan parameter Dapper.
- CORS hanya mengizinkan origin web yang diperlukan; sediakan origin localhost untuk development.
- Batasi panjang, format, dan rentang input di server. Validasi frontend bukan pengganti validasi backend.
- Semua query data pengguna terbatasi pada user dari token.
- Gunakan global exception handling dan `ProblemDetails`; detail exception hanya dicatat ke log server.
- Serilog mencatat waktu, level, route, status, dan correlation/request ID jika tersedia. Hindari data pribadi/credential dalam log.
- Token web gunakan pendekatan penyimpanan yang sesuai untuk demo dan jangan memasukkannya ke console/log. Flutter menggunakan penyimpanan aman seperti `flutter_secure_storage`.

## 11. Deployment dan Konfigurasi

- Backend: container/Docker atau host yang mendukung ASP.NET Core; deployment menggunakan konfigurasi environment.
- Database: PostgreSQL ter-host atau instance PostgreSQL yang dapat diakses backend.
- Web: Vercel/Netlify atau host static frontend. Set variabel `VITE_API_BASE_URL` ke API publik.
- Mobile: `flutter build apk --release`; pastikan base URL bukan `localhost` dan memakai alamat API publik HTTPS. Untuk Android emulator, `localhost` pada emulator bukan komputer host.
- Siapkan `.env.example` tanpa password/secret asli.
- Jangan membuat-buat URL publik. README menampilkan `TODO: isi setelah deploy` sampai deployment benar-benar selesai dan diverifikasi.

## 12. Dokumentasi yang Wajib Dibuat

Setiap repository memiliki `README.md` komprehensif berbahasa Indonesia, dengan:

1. Deskripsi dan fitur.
2. Stack teknologi.
3. Prasyarat dan versi runtime.
4. Langkah setup lokal yang dapat diikuti dari clone bersih.
5. Konfigurasi environment dan file `.env.example` tanpa secret.
6. Cara menyiapkan database serta menjalankan SQL schema/migration.
7. Perintah menjalankan dan build/test.
8. Arsitektur/pola desain.
9. Endpoint/integrasi yang relevan.
10. URL deployment yang sudah diverifikasi atau placeholder yang ditandai jelas.
11. Cara membuat, mengunduh, dan memasang APK (pada README mobile).
12. Troubleshooting dan screenshot (jika tersedia).

Dokumentasi tambahan di repository backend: `docs/API.md`, `docs/DATABASE.md`, `docs/DEPLOYMENT.md`, dan `docs/TESTING.md`. Sertakan contoh payload dan contoh curl yang tidak memuat credential asli.

## 13. Git dan Kualitas Kode

- Conventional Commits, misalnya `feat: add category CRUD endpoints`, `fix: prevent negative stock`, `docs: add local setup instructions`.
- Perubahan kecil dengan scope jelas; jalankan build/test sebelum commit.
- Jangan commit `.env`, JWT key, password, build output, token, atau file lokal yang bersifat privat.
- Jangan menghapus/mengganti file pengguna yang sudah ada sebelum memeriksa isinya.

## 14. Rencana Kerja 7 Hari

| Hari | Target | Hasil yang harus terlihat |
|---|---|---|
| 1 | Finalisasi SDK/tooling, struktur backend, database/schema, connection factory, Swagger, error handler, logging | API build dan koneksi PostgreSQL berhasil |
| 2 | Register/login JWT, CRUD kategori dan produk, validasi, SQL berparameter | Semua endpoint inti bisa diuji melalui Swagger |
| 3 | Transaksi stok, dashboard summary, isolasi data pengguna, smoke/integration tests, deploy API/database | Alur backend bekerja dan API publik dapat diuji |
| 4 | React auth, layout, dashboard, products/categories | Web dapat login dan mengambil data API |
| 5 | Form CRUD, movement/riwayat, loading/error, responsivitas, deploy web | Web MVP online dan terhubung API |
| 6 | Flutter auth, produk, kategori pilihan, pergerakan stok/riwayat, Provider dan token aman | Mobile terhubung ke API; debug build berjalan |
| 7 | APK release, end-to-end smoke test, perbaikan, docs, screenshots, GitHub sharing | APK siap diunduh; tiga README dan instruksi deployment lengkap |

Jika ada keterlambatan, utamakan fitur dan keamanan wajib; kurangi kosmetik/UI tambahan, bukan validasi, isolasi data, atau logika konsistensi stok.

## 15. Definition of Done

Proyek dianggap siap untuk penyerahan ketika:

- [ ] Backend build bersih dan terhubung ke PostgreSQL.
- [ ] Register/login/JWT bekerja.
- [ ] CRUD kategori dan produk lengkap dan terproteksi.
- [ ] Semua query data dibatasi menurut pemiliknya.
- [ ] Stok masuk/keluar mencatat history, stok tak pernah negatif, operasi transaksi atomik.
- [ ] Error, logging, validasi, dan Swagger tersedia.
- [ ] Web React memakai API nyata, responsif desktop/tablet, menampilkan feedback.
- [ ] Flutter memakai API nyata, navigasi dan state management bekerja, token disimpan dengan aman, APK release dapat dibuat.
- [ ] Backend dan web ter-deploy atau instruksi deployment konkret disediakan untuk langkah yang membutuhkan credential manual.
- [ ] Tiga repository memiliki README lengkap; tidak ada URL/hasil deployment fiktif.
- [ ] Tidak ada credential atau secret di Git history/file yang akan dibagikan.
- [ ] Git history memiliki commit bermakna.
- [ ] Repository dibagikan ke `ngertos@gmail.com` oleh pemilik repository.
