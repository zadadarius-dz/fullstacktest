# Prompt untuk Agentic — Mulai Mengerjakan StockMate

Salin prompt di bawah ke Agentic setelah membuka workspace proyek `C:\Users\rpada\StockMate`. Simpan atau lampirkan PRD `StockMate_PRD.md` di workspace, idealnya sebagai `docs/PRD.md`.

---

## PROMPT

Kamu adalah autonomous coding agent yang bertindak sebagai senior fullstack engineer. Tugasmu adalah **langsung memeriksa dan mengimplementasikan StockMate**, aplikasi inventory management untuk tes magang Fullstack Developer. Jangan hanya memberikan rencana, tutorial, atau snippet. Kerjakan file proyek yang nyata, jalankan build/test yang tersedia, perbaiki error yang kamu sebabkan, dan dokumentasikan hasil sebenarnya.

### Konteks lingkungan yang sudah diketahui

- Komputer menggunakan Windows.
- Workspace backend yang sudah ada: `C:\Users\rpada\StockMate`.
- Solution/API ASP.NET Core sudah dibuat dan Swagger pernah berhasil dibuka di `https://localhost:5131/swagger/index.html`.
- Template API saat ini kemungkinan masih berisi endpoint contoh `WeatherForecast`.
- SDK yang sebelumnya terdeteksi: .NET SDK `8.0.426`; Git tersedia.
- PostgreSQL baru saja dipasang/di-setup. Jangan mengasumsikan koneksi berhasil; verifikasi dengan aman. Jangan meminta pengguna mengirim password ke chat.
- Deadline pengerjaan: 7 hari. Utamakan MVP yang berfungsi, bukan fitur tambahan.

### Sumber kebutuhan

1. Baca `docs/PRD.md` atau file `StockMate_PRD.md` jika ada.
2. Jika PRD tidak ditemukan, jangan langsung berhenti: buat `docs/` dan tulis PRD ringkas dari ketentuan di bawah ini, lalu catat bahwa file PRD asli perlu disalin ke workspace.
3. PRD menjadi sumber kebenaran untuk requirement. Jangan menambahkan scope besar di luar MVP.

### Cara bekerja — wajib

1. Mulai dengan audit: lihat struktur folder, `git status`, solution, `.csproj`, `Program.cs`, konfigurasi, serta versi SDK/runtime yang terpasang. Jangan menimpa atau menghapus pekerjaan yang sudah ada sebelum memeriksanya.
2. Buat `docs/IMPLEMENTATION_PLAN.md` singkat dengan milestone dan blocker nyata. **Setelah membuat rencana, langsung lanjut coding; jangan berhenti untuk meminta persetujuan.**
3. Kerjakan milestone satu per satu. Jalankan build/test setelah setiap bagian penting dan perbaiki kesalahan yang disebabkan oleh perubahanmu.
4. Jika sebuah tool/SDK/database belum tersedia, lanjutkan pekerjaan lain yang bisa dikerjakan. Jelaskan blocker dan perintah yang perlu dijalankan pengguna. Jangan mengklaim build/test berhasil jika belum menjalankannya.
5. Jangan meminta atau menampilkan password, JWT secret, atau credential. Gunakan environment variables dan `.env.example` berisi placeholder. Jangan commit file `.env`, secret, atau connection string produksi.
6. Jangan mengarang URL deployment, akun demo, hasil tes, atau status publik. Gunakan `TODO` dengan jelas untuk hal yang memang perlu dilakukan manual.
7. Jangan push ke GitHub atau mengubah permission repository tanpa instruksi eksplisit. Buat perubahan lokal dan, bila memungkinkan, commit dengan Conventional Commits setelah milestone yang lolos build/test.
8. Setelah setiap milestone, laporkan ringkas file yang dibuat/diubah, perintah yang dijalankan, hasilnya, dan hal yang masih terblokir. Lalu lanjutkan ke milestone berikutnya tanpa menunggu persetujuan, kecuali benar-benar membutuhkan tindakan pengguna.

### Keputusan teknologi dan target framework

- Backend: ASP.NET Core Web API, Controllers, Dapper + Npgsql, PostgreSQL, JWT Bearer, BCrypt, Serilog, Swagger/OpenAPI.
- Web: React + Vite, JavaScript, React Router, Context API, Fetch API.
- Mobile: Flutter, Provider, `http`, dan penyimpanan token aman jika package/toolchain mendukung.
- Periksa `dotnet --list-sdks`. Jika SDK .NET 10 tersedia, gunakan `net10.0`. Jika hanya .NET 8 tersedia, jangan mengklaim .NET 10 sudah terpasang: pertahankan scaffold `net8.0` sementara agar progres tetap berjalan, dokumentasikan kebutuhan upgrade sebelum rilis/deployment, dan hindari mengubah target framework tanpa build yang berhasil.
- Jangan menginstal tool global atau mengubah konfigurasi mesin tanpa izin. Berikan instruksi manual jika perlu.

### Scope MVP StockMate

Aplikasi inventaris sederhana untuk satu pemilik data per akun:

- Register/login dan autentikasi JWT.
- CRUD kategori.
- CRUD produk: SKU, nama, kategori, deskripsi opsional, harga, stok minimum, stok aktif/nonaktif. Stok awal 0; edit produk tidak boleh mengubah jumlah stok.
- Catat pergerakan stok `IN` dan `OUT`, simpan riwayat, tolak quantity tidak positif dan stok keluar melebihi stok yang tersedia.
- Dashboard: jumlah produk, kategori, total unit stok, dan produk stok menipis.
- React web yang responsif, dan Flutter Android yang menggunakan API sama.
- Tidak perlu multi-gudang, supplier, barcode, invoice, PDF/Excel, notifikasi push, atau role admin yang kompleks.

### Aturan database dan keamanan

Buat schema/migration SQL yang bisa dijalankan ulang dengan instruksi jelas, dengan tabel `users`, `categories`, `products`, `stock_movements` serta FK, check constraints, unique constraints/index yang relevan.

- User hanya boleh melihat/mengubah data miliknya. Semua query kategori dan produk harus dibatasi oleh `user_id` dari klaim JWT, bukan dari body request.
- Password hanya disimpan sebagai hash BCrypt.
- Semua SQL harus berparameter; jangan gabungkan input pengguna ke SQL string.
- SKU unik per pengguna; nama kategori unik per pengguna tanpa membedakan kapitalisasi.
- Produk harus mengacu kategori milik pengguna yang login.
- Kategori yang sedang digunakan produk tidak dapat dihapus; balas `409 Conflict`.
- Produk yang dihapus menggunakan soft delete agar riwayat stok tetap utuh.
- `stock_movements` append-only: tidak ada edit/delete histori.
- Stok masuk/keluar dan insert riwayat harus dalam satu transaksi database; gunakan row lock atau strategi concurrency setara agar stok tidak negatif saat request bersamaan.
- Error response konsisten dan tidak mengekspos stack trace/secret. Logging tidak boleh mencatat password/token/secret.
- CORS hanya mengizinkan origin yang dikonfigurasi. Jangan gunakan wildcard bersama credential.

### REST API minimum

Semua endpoint selain register/login harus terlindungi JWT.

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET|POST /api/categories`
- `GET|PUT|DELETE /api/categories/{id}`
- `GET|POST /api/products`
- `GET|PUT|DELETE /api/products/{id}`
- `POST /api/products/{id}/movements`
- `GET /api/products/{id}/movements`
- `GET /api/stock-movements`
- `GET /api/dashboard/summary`

Gunakan DTO untuk request/response, validasi server, status HTTP yang benar, pagination dengan batas maksimum `pageSize`, dan pencarian aman. Tambahkan contoh request/response ke README atau dokumentasi API.

### Urutan eksekusi

#### Milestone 0 — Audit
- Audit workspace, Git, SDK, PostgreSQL connection/config, dan PRD.
- Buat `docs/IMPLEMENTATION_PLAN.md` serta catat kondisi awal.
- Langsung lanjut ke milestone 1.

#### Milestone 1 — Backend dan database
- Pertahankan proyek `StockMate.Api` yang sudah ada.
- Atur folder modular: `Controllers`, `DTOs`, `Models`, `Services`, `Repositories`, `Data`, `Middleware`.
- Siapkan koneksi PostgreSQL melalui environment/config tanpa menyimpan password di source control.
- Buat `Data/Migrations/001_initial_schema.sql` atau lokasi migration yang konsisten; sertakan cara menjalankan via pgAdmin Query Tool.
- Tambahkan Dapper/Npgsql, dependency injection, global exception handler, Serilog, Swagger, CORS, dan JWT configuration.
- Hapus endpoint `WeatherForecast` hanya saat endpoint StockMate mulai menggantikannya dan build masih berhasil.
- Jalankan `dotnet restore` dan `dotnet build`.

#### Milestone 2 — Auth, kategori, dan produk
- Implementasikan register/login, BCrypt, JWT signing key dari environment, DTO, validasi, dan endpoint CRUD.
- Terapkan isolasi data per user dan semua aturan bisnis di atas.
- Jalankan build dan tambahkan tes yang masuk akal.

#### Milestone 3 — Pergerakan stok dan dashboard
- Implementasikan IN/OUT secara atomik di database.
- Tambahkan daftar riwayat dan dashboard summary.
- Tes kasus penting: quantity 0/negatif, stok keluar melebihi stok, SKU duplikat, kategori terpakai, token tidak valid, dan user A mencoba mengakses data user B.

#### Milestone 4 — React web
- Buat sibling folder/repository `stockmate-web` tanpa membuat nested Git repo yang tidak disengaja.
- Halaman minimum: register/login, dashboard, CRUD kategori, CRUD produk, transaksi IN/OUT, riwayat.
- Buat API client Fetch terpusat dengan bearer token, penanganan non-2xx, loading/empty/error/success, validasi form, route terlindungi, dan responsive desktop/tablet.
- Base URL berasal dari `VITE_API_BASE_URL`, bukan URL produksi yang dibuat-buat.
- Jalankan `npm install`, `npm run build`, dan lint bila tersedia.

#### Milestone 5 — Flutter mobile
- Buat sibling folder/repository `stockmate-mobile` tanpa membuat nested Git repo yang tidak disengaja.
- Gunakan Provider dan `http`; pisahkan `models`, `services`, `providers`, `screens`, serta widget umum.
- Halaman minimum: login/register, dashboard sederhana, daftar/detail produk, tambah/edit produk, transaksi IN/OUT, riwayat, logout.
- Tambahkan loading/error/success, form validation, token handling, dan API base URL yang mudah dikonfigurasi.
- Jangan memakai `localhost` untuk API publik atau perangkat fisik. Gunakan base URL konfigurasi.
- Jika Flutter/Android SDK ada, jalankan `flutter pub get`, `flutter analyze`, dan build APK release. Target artefak: `build/app/outputs/flutter-apk/app-release.apk`. Jika tidak tersedia, tuliskan langkah setup dan jangan mengklaim APK sudah dibuat.

#### Milestone 6 — Dokumentasi dan final review

Buat README yang benar-benar sesuai implementasi untuk tiap repository:

- Deskripsi dan fitur.
- Teknologi serta gambaran arsitektur.
- Prasyarat dan langkah setup lokal.
- Konfigurasi environment dalam bentuk contoh tanpa secret.
- Setup/migrasi database.
- Cara menjalankan dan menguji.
- Endpoint API dan contoh payload.
- Cara build Flutter APK.
- Deployment: link hanya diisi setelah deployment nyata; jika belum, tulis `Belum di-deploy` dan langkah manual.
- Screenshot hanya jika file screenshot memang tersedia.

Tambahkan juga `docs/ARCHITECTURE.md`, `docs/API.md` atau gunakan Swagger sebagai dokumentasi interaktif, serta `docs/DEPLOYMENT.md` bila waktunya memungkinkan. Pastikan ketiga repository memiliki README.

### Kondisi selesai (Definition of Done)

- Backend build berhasil.
- Schema SQL tersedia dan instruksi setup jelas.
- API auth + CRUD kategori/produk + movement + dashboard terimplementasi.
- Aturan akses data antar pengguna dan pencegahan stok negatif diterapkan.
- Web build berhasil jika Node tersedia.
- Flutter analyze/build dilakukan jika Flutter tersedia.
- Swagger menampilkan endpoint StockMate, bukan hanya `WeatherForecast`.
- README setiap repository tersedia dan tidak berisi klaim palsu.
- Semua blocker manual dicatat jelas.

### Mulai sekarang

Pertama lakukan audit workspace dan tulis kondisi awal secara ringkas. Setelah itu **langsung implementasikan Milestone 1 di file proyek yang ada**. Jangan hanya membalas dengan rencana. Jika ada blocker PostgreSQL, siapkan kode, schema, konfigurasi contoh, dan petunjuk penyelesaian koneksi tanpa meminta password pengguna. Setelah Milestone 1 lulus build, lanjutkan ke Milestone 2 dan berikutnya selama lingkungan memungkinkan.
