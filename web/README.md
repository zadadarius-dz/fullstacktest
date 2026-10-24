# StockMate Web

Aplikasi web untuk **StockMate — Simple Inventory Management System**. Dibangun dengan React 19 + Vite, berkomunikasi dengan StockMate REST API.

> **Status verifikasi:** `npm run lint` bersih dan `npm run build` berhasil (Vite 8.3.5, 53 modul). Belum ada deployment, URL publik, atau E2E test otomatis. Detail ada di [`../docs/TESTING.md`](../docs/TESTING.md).

## 1. Fitur

- Register dan login dengan JWT.
- Sesi disimpan di `localStorage`; logout membersihkan sesi.
- Rute terproteksi: halaman aplikasi hanya dapat diakses setelah login.
- Dashboard ringkasan: produk aktif, kategori, total unit, stok menipis.
- CRUD kategori dengan konfirmasi dan penanganan konflik.
- Daftar produk: pencarian, filter kategori, filter stok menipis, pagination.
- Form produk: create/edit, validasi, stok awal 0, edit tidak mengubah stok.
- Detail produk: informasi lengkap, form transaksi `IN`/`OUT`, riwayat per produk.
- Halaman riwayat seluruh pergerakan stok.
- Soft delete produk.
- State loading, empty, error, dan sukses pada setiap alur.
- Layout responsif (mobile, tablet, desktop).
- Penanganan `ProblemDetails` dari API dengan pesan yang dapat dibaca.
- Sesi kedaluwarsa (`401`) otomatis mengarahkan ke login.

## 2. Stack

| Komponen | Versi |
|---|---|
| React | 19.3.1 |
| React DOM | 19.3.1 |
| React Router | 7.18.4 |
| Vite | 8.3.4 (terpasang 8.3.5) |
| Oxlint | 1.88.0 |
| Node.js (saat verifikasi) | 24.18.0 |
| npm (saat verifikasi) | 11.16.0 |

State global autentikasi memakai Context API. Data fetching memakai Fetch API melalui satu modul `src/api/client.js`; tidak ada library state/data tambahan.

## 3. Prasyarat

- Node.js 20+ dan npm (verifikasi memakai Node 24).
- Backend StockMate berjalan dan dapat diakses.
- CORS backend mengizinkan origin web (default `http://localhost:5173` dan `http://127.0.0.1:5173`).

## 4. Menjalankan lokal

```powershell
cd C:\projects\stockmate\web
npm install
```

Buat file `.env.local` (tidak di-commit):

```text
VITE_API_BASE_URL=http://localhost:5131
```

Lalu:

```powershell
npm run dev
```

Buka URL yang ditampilkan Vite, biasanya `http://localhost:5173`.

Jika `VITE_API_BASE_URL` tidak diisi, aplikasi memakai `http://localhost:5131` sebagai fallback **hanya untuk pengembangan**. Untuk build produksi, selalu set variabel secara eksplisit.

### Menjalankan backend

```powershell
cd C:\projects\stockmate
dotnet run --project StockMate.Api
```

Pastikan `ConnectionStrings__DefaultConnection` dan (untuk Production) `Jwt__SigningKey` sudah diisi melalui environment. Lihat [`../README.md`](../README.md).

## 5. Environment variable

| Variabel | Wajib | Contoh | Keterangan |
|---|---|---|---|
| `VITE_API_BASE_URL` | Untuk build produksi | `https://api.example.com` | Base URL API tanpa trailing slash. |

Catatan:

- Variabel `VITE_*` **tertanam di bundle** dan terlihat oleh browser. Jangan pernah menaruh secret di sini.
- Setelah mengubah nilai, jalankan ulang `npm run dev` atau build ulang.
- Jangan commit `.env`, `.env.local`, atau `.env.production` bila berisi nilai internal. `.gitignore` sudah mengecualikan file `.env*`.

## 6. Script

| Perintah | Fungsi |
|---|---|
| `npm run dev` | Menjalankan dev server Vite dengan HMR. |
| `npm run build` | Build produksi ke `dist/`. |
| `npm run preview` | Menyajikan hasil build secara lokal. |
| `npm run lint` | Menjalankan Oxlint. |

Verifikasi terakhir:

```text
npm run lint   → bersih
npm run build  → 53 modules transformed, built in 905ms
                 dist/assets/index-*.js   303.05 kB (gzip 92.14 kB)
                 dist/assets/index-*.css   14.26 kB (gzip 3.72 kB)
```

## 7. Struktur proyek

```text
src/
  api/          client.js (fetch, token, error), auth, categories, products, movements, dashboard
  components/   Alert, EmptyState, Modal, Pagination, ProtectedRoute, Spinner, StatCard
  context/      AuthContext + useAuth
  layouts/      AuthLayout, AppLayout
  pages/        Login, Register, Dashboard, Categories, Products, ProductForm,
                ProductDetail, Movements, NotFound
  routes/       AppRoutes.jsx
  utils/        format.js, validation.js
  App.jsx
  main.jsx
  index.css
public/         favicon.svg, icons.svg
```

### Rute

| Rute | Halaman | Akses |
|---|---|---|
| `/login` | Login | Publik |
| `/register` | Register | Publik |
| `/` | Redirect ke `/dashboard` | Terproteksi |
| `/dashboard` | Dashboard | Terproteksi |
| `/products` | Daftar produk | Terproteksi |
| `/products/new` | Form produk baru | Terproteksi |
| `/products/:id` | Detail produk + transaksi + riwayat | Terproteksi |
| `/products/:id/edit` | Edit produk | Terproteksi |
| `/categories` | Kategori | Terproteksi |
| `/movements` | Riwayat seluruh stok | Terproteksi |
| `*` | 404 | Publik |

## 8. Alur autentikasi

1. Login/register mengirim kredensial ke API dan menerima `accessToken`.
2. Token dan profil disimpan di `localStorage` (`stockmate_token`, `stockmate_user`).
3. `src/api/client.js` menambahkan header `Authorization: Bearer <token>` pada request terautentikasi.
4. Respons `401` memicu event `stockmate:unauthorized`; `AuthContext` membersihkan sesi dan mengarahkan ke `/login`.
5. Logout menghapus token dan profil.

`localStorage` dipilih karena kesederhanaan MVP. Untuk kebutuhan keamanan lebih tinggi, pertimbangkan cookie `HttpOnly` + refresh token di iterasi berikutnya. Ini belum diimplementasikan.

## 9. Penanganan error

- `ProblemDetails.detail`, `ProblemDetails.title`, atau pesan validasi pertama ditampilkan ke pengguna.
- Kegagalan jaringan menampilkan pesan yang menyarankan pemeriksaan koneksi dan `VITE_API_BASE_URL`.
- `409` (stok tidak cukup / duplikat / kategori dipakai) ditampilkan sebagai pesan yang jelas, bukan crash.
- `401` memicu logout otomatis.
- `404` produk/kategori menampilkan state kosong yang sesuai.

## 10. Build dan deploy

```powershell
npm run lint
npm run build
```

Hasil ada di `dist/`. Untuk hosting:

- Set `VITE_API_BASE_URL` ke URL API produksi **sebelum** build.
- Konfigurasikan SPA fallback ke `index.html`.
- Aktifkan HTTPS.
- Tambahkan origin web ke `Cors__AllowedOrigins__N` di backend.

Panduan lengkap: [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).

### Status deployment

| Item | Status |
|---|---|
| URL web | `TODO: isi setelah deploy` |
| Backend yang dipakai | `TODO: isi setelah deploy` |

Belum ada deployment yang dilakukan.

## 11. Troubleshooting

| Gejala | Penyebab | Tindakan |
|---|---|---|
| `Tidak dapat terhubung ke server` | API mati atau URL salah | Jalankan backend; periksa `VITE_API_BASE_URL`. |
| CORS error di console | Origin tidak terdaftar | Tambahkan origin ke `Cors__AllowedOrigins__N`, restart API. |
| Login berhasil lalu langsung logout | Signing key berubah / token kedaluwarsa | Login ulang; pastikan key API stabil. |
| Halaman 404 saat refresh di hosting | SPA fallback belum diatur | Arahkan semua rute ke `index.html`. |
| Data tidak muncul setelah ganti environment | Build lama masih memakai URL lama | Build ulang setelah mengubah `VITE_*`. |
| `npm run build` gagal | Dependency belum terpasang | Jalankan `npm install` (atau `npm ci`). |

## 12. Yang belum ada

- Unit/component test dan E2E test.
- Refresh token.
- Internasionalisasi (UI saat ini berbahasa Indonesia).
- Dark mode.
- Optimasi lanjutan (code splitting manual, PWA).
- Deployment produksi.

Item di atas adalah pengembangan lanjutan, bukan fitur yang sudah selesai.
