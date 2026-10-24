# StockMate — Database

**Database:** PostgreSQL 13+ (diuji pada PostgreSQL 18.6)  
**Schema file:** [`StockMate.Api/Data/Migrations/001_initial_schema.sql`](../StockMate.Api/Data/Migrations/001_initial_schema.sql)  
**Status:** schema berhasil dijalankan dan dijalankan ulang (idempoten) pada database test lokal.

Dokumen ini menjelaskan struktur data, constraint, index, alur transaksi stok, dan prosedur operasional. Tidak ada credential di dalam dokumen ini.

## 1. Prinsip desain

1. **Isolasi per pengguna.** Semua tabel bisnis memiliki `user_id` atau `created_by_user_id`. Query aplikasi selalu memfilter dengan ID dari klaim JWT `sub`.
2. **Integritas di level database.** Tipe movement, quantity positif, stok tidak negatif, dan konsistensi `stock_before`/`stock_after` dijaga oleh `CHECK CONSTRAINT`, bukan hanya validasi aplikasi.
3. **Kepemilikan dijaga relasi komposit.** Produk tidak bisa memakai kategori milik pengguna lain, dan movement tidak bisa merujuk produk milik pengguna lain.
4. **Riwayat append-only.** `stock_movements` tidak memiliki endpoint update/delete. Baris riwayat menjadi jejak audit.
5. **Soft delete produk.** `products.is_active = false`; baris dan riwayatnya tetap ada.
6. **Waktu dalam UTC.** Semua kolom waktu memakai `TIMESTAMPTZ` dengan default `NOW()`.

## 2. ERD

```text
┌──────────────────────┐
│ users                │
├──────────────────────┤
│ id            PK     │
│ name                 │
│ email         UQ*    │  * unik pada lower(email)
│ password_hash        │
│ created_at           │
│ updated_at           │
└──────────┬───────────┘
           │ 1
           │
           │ N
┌──────────▼───────────┐          ┌───────────────────────────┐
│ categories           │ 1      N │ products                  │
├──────────────────────┤◄─────────├───────────────────────────┤
│ id            PK     │          │ id                 PK     │
│ user_id       FK     │          │ user_id            FK     │
│ name                 │          │ category_id        FK─────┘ (komposit)
│ created_at           │          │ sku                UQ per user
│ updated_at           │          │ name                      │
└──────────────────────┘          │ description               │
                                  │ price                     │
                                  │ stock_quantity            │
                                  │ min_stock                 │
                                  │ is_active                 │
                                  │ created_at / updated_at   │
                                  └─────────────┬─────────────┘
                                                │ 1
                                                │
                                                │ N
                                  ┌─────────────▼─────────────┐
                                  │ stock_movements           │
                                  ├───────────────────────────┤
                                  │ id                 PK     │
                                  │ product_id         FK─────┘ (komposit)
                                  │ created_by_user_id FK     │
                                  │ type (IN/OUT)             │
                                  │ quantity                  │
                                  │ stock_before              │
                                  │ stock_after               │
                                  │ note                      │
                                  │ created_at                │
                                  └───────────────────────────┘
```

Relasi:

| Dari | Ke | Kardinalitas | On delete |
|---|---|---|---|
| `categories.user_id` | `users.id` | N:1 | `CASCADE` |
| `products.user_id` | `users.id` | N:1 | `CASCADE` |
| `products (category_id, user_id)` | `categories (id, user_id)` | N:1 | `RESTRICT` |
| `stock_movements.created_by_user_id` | `users.id` | N:1 | `CASCADE` |
| `stock_movements (product_id, created_by_user_id)` | `products (id, user_id)` | N:1 | `RESTRICT` |

`ON DELETE CASCADE` pada `users` berarti menghapus pengguna akan menghapus seluruh datanya. `RESTRICT` pada produk/kategori mencegah penghapusan fisik yang membuat riwayat menggantung. Aplikasi sendiri tidak menghapus pengguna maupun produk secara fisik.

## 3. Definisi tabel

### 3.1 `users`

| Kolom | Tipe | Null | Default | Keterangan |
|---|---|---|---|---|
| `id` | `UUID` | tidak | `gen_random_uuid()` | Primary key. |
| `name` | `VARCHAR(100)` | tidak | – | Nama tampilan, minimal 2 karakter setelah trim. |
| `email` | `VARCHAR(255)` | tidak | – | Disimpan lowercase oleh aplikasi. |
| `password_hash` | `TEXT` | tidak | – | Hash BCrypt; tidak pernah dikembalikan API. |
| `created_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Waktu pembuatan. |
| `updated_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Diperbarui trigger. |

Constraint/index:

- `PK users(id)`
- `chk_users_name_not_blank`: `length(btrim(name)) >= 2`
- `ux_users_email_lower`: unique pada `lower(email)`
- `trg_users_updated_at`: trigger `BEFORE UPDATE`

### 3.2 `categories`

| Kolom | Tipe | Null | Default | Keterangan |
|---|---|---|---|---|
| `id` | `UUID` | tidak | `gen_random_uuid()` | Primary key. |
| `user_id` | `UUID` | tidak | – | Pemilik; FK ke `users.id`. |
| `name` | `VARCHAR(80)` | tidak | – | Nama kategori. |
| `created_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Waktu pembuatan. |
| `updated_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Diperbarui trigger. |

Constraint/index:

- `PK categories(id)`
- `fk_categories_user`: `user_id → users(id) ON DELETE CASCADE`
- `uq_categories_id_user`: unique `(id, user_id)` — dipakai composite FK produk.
- `chk_categories_name_length`: `length(btrim(name)) BETWEEN 2 AND 80`
- `ux_categories_user_name_lower`: unique `(user_id, lower(btrim(name)))`
- `idx_categories_user_created`: `(user_id, created_at DESC)`

### 3.3 `products`

| Kolom | Tipe | Null | Default | Keterangan |
|---|---|---|---|---|
| `id` | `UUID` | tidak | `gen_random_uuid()` | Primary key. |
| `user_id` | `UUID` | tidak | – | Pemilik; FK ke `users.id`. |
| `category_id` | `UUID` | tidak | – | Kategori pemilik yang sama. |
| `sku` | `VARCHAR(64)` | tidak | – | Disimpan uppercase dan trim oleh API. |
| `name` | `VARCHAR(160)` | tidak | – | Nama produk. |
| `description` | `VARCHAR(500)` | ya | – | Opsional. |
| `price` | `NUMERIC(14,2)` | tidak | `0` | Harga satuan, tidak negatif. |
| `stock_quantity` | `INTEGER` | tidak | `0` | Stok saat ini, tidak negatif. |
| `min_stock` | `INTEGER` | tidak | `0` | Ambang stok menipis. |
| `is_active` | `BOOLEAN` | tidak | `TRUE` | `false` = soft delete. |
| `created_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Waktu pembuatan. |
| `updated_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Diperbarui trigger. |

Constraint/index:

- `PK products(id)`
- `fk_products_user`: `user_id → users(id) ON DELETE CASCADE`
- `fk_products_category_owner`: `(category_id, user_id) → categories(id, user_id) ON DELETE RESTRICT`
- `uq_products_id_user`: unique `(id, user_id)` — dipakai composite FK movement.
- `chk_products_price_non_negative`: `price >= 0`
- `chk_products_stock_non_negative`: `stock_quantity >= 0`
- `chk_products_min_stock_non_negative`: `min_stock >= 0`
- `chk_products_name_length`: `length(btrim(name)) BETWEEN 2 AND 160`
- `chk_products_sku_not_blank`: `length(btrim(sku)) BETWEEN 1 AND 64`
- `ux_products_user_sku`: unique `(user_id, sku)`
- `idx_products_user_active`: `(user_id, is_active, created_at DESC)`
- `idx_products_category`: `(category_id)`
- `idx_products_user_name_lower`: `(user_id, lower(name))`
- `idx_products_user_sku_lower`: `(user_id, lower(sku))`

Index `lower(name)` dan `lower(sku)` mendukung pencarian case-insensitive. Filter `lowStock` memakai perbandingan `stock_quantity <= min_stock`.

### 3.4 `stock_movements`

| Kolom | Tipe | Null | Default | Keterangan |
|---|---|---|---|---|
| `id` | `UUID` | tidak | `gen_random_uuid()` | Primary key. |
| `product_id` | `UUID` | tidak | – | Produk yang bergerak. |
| `created_by_user_id` | `UUID` | tidak | – | Pemilik produk. |
| `type` | `VARCHAR(3)` | tidak | – | `IN` atau `OUT`. |
| `quantity` | `INTEGER` | tidak | – | Harus > 0. |
| `stock_before` | `INTEGER` | tidak | – | Stok sebelum transaksi. |
| `stock_after` | `INTEGER` | tidak | – | Stok setelah transaksi. |
| `note` | `VARCHAR(300)` | ya | – | Catatan opsional. |
| `created_at` | `TIMESTAMPTZ` | tidak | `NOW()` | Waktu pencatatan. |

Constraint/index:

- `PK stock_movements(id)`
- `fk_stock_movements_user`: `created_by_user_id → users(id) ON DELETE CASCADE`
- `fk_stock_movements_product_owner`: `(product_id, created_by_user_id) → products(id, user_id) ON DELETE RESTRICT`
- `chk_stock_movements_type`: `type IN ('IN','OUT')`
- `chk_stock_movements_quantity_positive`: `quantity > 0`
- `chk_stock_movements_stock_before_non_negative`: `stock_before >= 0`
- `chk_stock_movements_stock_after_non_negative`: `stock_after >= 0`
- `chk_stock_movements_out_reduces_stock`: `type <> 'OUT' OR stock_after = stock_before - quantity`
- `chk_stock_movements_in_increases_stock`: `type <> 'IN' OR stock_after = stock_before + quantity`
- `idx_stock_movements_product_created`: `(product_id, created_at DESC)`
- `idx_stock_movements_user_created`: `(created_by_user_id, created_at DESC)`

Tidak ada `updated_at` dan tidak ada trigger update: tabel ini append-only.

## 4. Alur transaksi stok

Pencatatan movement dijalankan oleh `StockMovementRepository` dalam satu transaksi database:

1. `BEGIN`
2. `SELECT ... FROM products WHERE id = @productId AND user_id = @userId FOR UPDATE`
   - Baris produk dikunci sehingga dua request bersamaan tidak membaca stok yang sama.
   - Bila produk tidak ada, tidak aktif, atau bukan milik pengguna → `404`.
3. Hitung stok baru:
   - `IN`  → `stock_before + quantity`
   - `OUT` → `stock_before - quantity`; bila hasil < 0 → rollback dan `409 Conflict`.
4. `UPDATE products SET stock_quantity = @stockAfter`
5. `INSERT INTO stock_movements (...)`
6. `COMMIT`

Karena update stok dan insert riwayat berada di transaksi yang sama, tidak ada kondisi stok berubah tanpa riwayat atau sebaliknya. Constraint database menjadi pengaman terakhir bila ada bug aplikasi.

### Uji konkurensi

Integration test menjalankan **20 request `OUT` bersamaan** terhadap produk dengan stok 10:

| Hasil | Jumlah |
|---|---|
| `201 Created` | 10 |
| `409 Conflict` | 10 |
| Stok akhir | `0` |
| Total movement tercatat | 10 |

Tidak ada stok negatif dan tidak ada oversell.

## 5. Isolasi data

- `user_id` tidak pernah berasal dari body atau query string. `CurrentUserService` membaca klaim `sub` dari token yang sudah divalidasi.
- Setiap `SELECT`, `UPDATE`, dan `DELETE` menyertakan `user_id = @userId`.
- Resource milik pengguna lain dikembalikan sebagai `404`, bukan `403`, agar keberadaannya tidak terbocorkan.
- Composite FK mencegah penulisan langsung ke database yang mencampur kepemilikan.
- Integration test memverifikasi bahwa pengguna kedua tidak dapat membaca atau mengubah data pengguna pertama.

## 6. Menjalankan schema

### Opsi A — `psql`

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h localhost -p 5432 -U stockmate_app -d stockmate `
  -f "C:\projects\stockmate\StockMate.Api\Data\Migrations\001_initial_schema.sql"
```

`psql` akan meminta password secara interaktif.

### Opsi B — pgAdmin

1. Hubungkan ke instance PostgreSQL.
2. Buka database `stockmate`.
3. Query Tool → buka `001_initial_schema.sql` → Execute.

### Opsi C — auto-migrate saat start

Set `Database__AutoMigrate=true`. API menjalankan file yang sama saat startup. Untuk produksi, langkah migration terpisah lebih mudah diaudit.

### Verifikasi

```sql
\dt
\d+ products
\d+ stock_movements
```

Empat tabel yang diharapkan: `users`, `categories`, `products`, `stock_movements`.

## 7. Sifat idempoten

Script memakai `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, dan `DROP TRIGGER IF EXISTS` sebelum `CREATE TRIGGER`. Menjalankan ulang script tidak menghapus data dan tidak menggandakan objek. Script dibungkus `BEGIN ... COMMIT`, sehingga kegagalan di tengah proses akan rollback.

> Script ini adalah baseline awal, bukan sistem migration berversi. Perubahan schema berikutnya sebaiknya ditambahkan sebagai file baru (mis. `002_...sql`) dan dicatat di dokumen ini.

## 8. Backup dan restore

Contoh dengan `pg_dump` (password diminta interaktif):

```powershell
# Backup
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" `
  -h localhost -p 5432 -U stockmate_app -Fc -d stockmate `
  -f "C:\backup\stockmate-$(Get-Date -Format yyyyMMdd-HHmm).dump"

# Restore ke database kosong
& "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" `
  -h localhost -p 5432 -U stockmate_app -d stockmate_restore `
  "C:\backup\stockmate-20261024-1200.dump"
```

- Simpan backup di luar repository dan enkripsi bila berisi data nyata.
- Uji restore secara berkala ke database terpisah.
- Jangan commit file `.dump`/`.sql` hasil backup.

## 9. Reset database development

> **Peringatan:** menghapus tabel berarti menghapus seluruh data. Hanya lakukan pada database development/test.

```sql
DROP TABLE IF EXISTS stock_movements;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;
DROP FUNCTION IF EXISTS set_updated_at();
```

Lalu jalankan ulang `001_initial_schema.sql`. Urutan drop mengikuti arah foreign key.

Alternatif cepat: buat database baru, jalankan schema, lalu arahkan connection string ke database tersebut.

## 10. Database test

Integration test memakai database terpisah melalui `STOCKMATE_TEST_DATABASE`. Test factory mengaktifkan auto-migrate dan membersihkan data antar test.

```powershell
$env:STOCKMATE_TEST_DATABASE = 'Host=localhost;Port=5432;Database=stockmate_test;Username=stockmate_app;Password=<password-anda>'
dotnet test StockMate.sln
```

Aturan:

- **Jangan** memakai database produksi atau database kerja utama.
- Test akan **skip** (bukan gagal) bila variabel tidak diisi.
- Buat database test kosong terlebih dahulu; test membuat schema yang dibutuhkan.

## 11. Catatan performa

- Query daftar produk memakai pagination (`LIMIT`/`OFFSET`) dan index `(user_id, is_active, created_at DESC)`.
- Pencarian memakai `ILIKE` pada nama/SKU; index `lower(...)` membantu, tetapi untuk dataset sangat besar pertimbangkan `pg_trgm`.
- `SELECT ... FOR UPDATE` hanya mengunci satu baris produk, bukan seluruh tabel, sehingga transaksi pada produk berbeda tetap paralel.
- Riwayat diurutkan `created_at DESC` dan dilayani index `(product_id, created_at DESC)` serta `(created_by_user_id, created_at DESC)`.
- Harga memakai `NUMERIC(14,2)`, bukan floating point, agar tidak ada pembulatan biner.

## 12. Hal yang belum ada

- Migration berversi otomatis (mis. Flyway/EF migrations).
- Partisi tabel `stock_movements` untuk volume sangat besar.
- Retensi/arsip riwayat.
- Row-level security PostgreSQL (isolasi saat ini diterapkan di lapisan aplikasi + composite FK).

Item di atas tidak diperlukan untuk scope MVP dan ditandai sebagai pengembangan lanjutan, bukan fitur yang sudah selesai.
