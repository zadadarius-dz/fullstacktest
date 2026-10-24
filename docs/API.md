# StockMate API — Referensi Endpoint

**Base URL lokal:** `http://localhost:5131`  
**Format:** JSON, properti `camelCase`  
**Autentikasi:** `Authorization: Bearer <accessToken>` untuk semua endpoint kecuali register dan login.

Dokumen ini memakai placeholder `$API_URL` dan `$TOKEN`. Tidak ada credential asli di dalam contoh.

```bash
export API_URL="http://localhost:5131"
export TOKEN="<access-token-dari-login>"
```

## 1. Format respons umum

### Sukses

- `200 OK` untuk GET/PUT.
- `201 Created` untuk POST yang membuat resource.
- `204 No Content` untuk DELETE.

### Error

Error menggunakan `application/problem+json` dengan struktur `ProblemDetails`:

```json
{
  "status": 409,
  "title": "Konflik data",
  "detail": "SKU sudah digunakan.",
  "instance": "/api/products",
  "traceId": "0HN..."
}
```

| Status | Makna |
|---|---|
| `400 Bad Request` | Validasi input gagal atau format request tidak valid. |
| `401 Unauthorized` | Token tidak ada, tidak valid, atau kedaluwarsa. |
| `403 Forbidden` | Akses ditolak (tidak digunakan pada alur normal MVP). |
| `404 Not Found` | Resource tidak ada **atau** bukan milik pengguna. |
| `409 Conflict` | Duplikat data, kategori masih dipakai, atau stok tidak mencukupi. |
| `500 Internal Server Error` | Error tak terduga; detail internal hanya di log server. |

Untuk request body yang gagal validasi, respons dapat berbentuk `ValidationProblemDetails` dengan properti `errors`:

```json
{
  "status": 400,
  "title": "Validasi gagal",
  "detail": "Periksa kembali data yang dikirim.",
  "instance": "/api/auth/register",
  "traceId": "0HN...",
  "errors": {
    "Email": ["Format email tidak valid."]
  }
}
```

## 2. Autentikasi

### 2.1 Register

```http
POST /api/auth/register
Content-Type: application/json
```

```json
{
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "Password123!"
}
```

Aturan:

- `name`: 2–100 karakter setelah trim.
- `email`: format email valid, maksimal 255 karakter, dinormalisasi ke lowercase.
- `password`: 8–72 karakter; BCrypt hanya memproses maksimal 72 byte.
- Email unik tanpa membedakan kapitalisasi.

Respons `201 Created`:

```json
{
  "accessToken": "<jwt>",
  "tokenType": "Bearer",
  "expiresAt": "2026-10-24T12:00:00+00:00",
  "user": {
    "id": "0f8fad5b-d9cb-469f-a165-70867728950e",
    "name": "Budi Santoso",
    "email": "budi@example.com",
    "createdAt": "2026-10-24T10:00:00+00:00"
  }
}
```

Kemungkinan error: `400` validasi, `409` email sudah terdaftar.

### 2.2 Login

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "email": "budi@example.com",
  "password": "Password123!"
}
```

Respons `200 OK` sama dengan respons register. Error: `401` bila email/password salah.

### 2.3 Profil pengguna aktif

```http
GET /api/auth/me
Authorization: Bearer $TOKEN
```

Respons `200 OK`:

```json
{
  "id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "createdAt": "2026-10-24T10:00:00+00:00"
}
```

## 3. Kategori

Semua endpoint kategori memerlukan Bearer token dan hanya mengakses data milik pengguna dari klaim `sub`.

### 3.1 Daftar kategori

```http
GET /api/categories
Authorization: Bearer $TOKEN
```

Respons `200 OK`:

```json
[
  {
    "id": "ca1d41c8-facd-4046-94c0-27d51354dd6f",
    "name": "Minuman",
    "createdAt": "2026-10-24T10:01:00+00:00",
    "updatedAt": "2026-10-24T10:01:00+00:00"
  }
]
```

### 3.2 Detail kategori

```http
GET /api/categories/{id}
Authorization: Bearer $TOKEN
```

Respons `200 OK` atau `404` bila tidak ada/bukan milik pengguna.

### 3.3 Membuat kategori

```http
POST /api/categories
Authorization: Bearer $TOKEN
Content-Type: application/json
```

```json
{
  "name": "Minuman"
}
```

Aturan: nama 2–80 karakter setelah trim; unik per pengguna tanpa membedakan kapitalisasi.

Respons `201 Created` dengan header `Location` menuju detail kategori.

Error: `400` validasi, `409` nama kategori sudah digunakan.

### 3.4 Memperbarui kategori

```http
PUT /api/categories/{id}
Authorization: Bearer $TOKEN
Content-Type: application/json
```

```json
{
  "name": "Minuman Dingin"
}
```

Respons `200 OK` dengan data terbaru. Error: `400`, `404`, `409`.

### 3.5 Menghapus kategori

```http
DELETE /api/categories/{id}
Authorization: Bearer $TOKEN
```

Respons `204 No Content`.

Kategori **tidak dapat dihapus** bila masih dipakai produk; API mengembalikan `409 Conflict`.

## 4. Produk

### 4.1 Daftar produk

```http
GET /api/products?page=1&pageSize=10&search=kopi&categoryId=<uuid>&lowStock=false
Authorization: Bearer $TOKEN
```

Query parameter:

| Parameter | Default | Keterangan |
|---|---|---|
| `page` | `1` | Halaman, minimal 1. |
| `pageSize` | `10` | 1–100; nilai lebih besar dibatasi 100. |
| `search` | kosong | Cari pada nama atau SKU (case-insensitive), maksimal 100 karakter. |
| `categoryId` | kosong | Filter kategori milik pengguna. |
| `lowStock` | `false` | `true` untuk produk dengan `stock_quantity <= min_stock`. |

Hanya produk aktif yang dikembalikan. Respons `200 OK`:

```json
{
  "items": [
    {
      "id": "3b6d9a4e-2f4f-4f3c-9f6f-4a4d6e7f8a90",
      "sku": "KOPI-001",
      "name": "Kopi Arabica 250g",
      "categoryId": "ca1d41c8-facd-4046-94c0-27d51354dd6f",
      "categoryName": "Minuman",
      "description": "Biji kopi arabica",
      "price": 75000.00,
      "stockQuantity": 7,
      "minStock": 5,
      "isActive": true,
      "createdAt": "2026-10-24T10:02:00+00:00",
      "updatedAt": "2026-10-24T10:03:00+00:00"
    }
  ],
  "page": 1,
  "pageSize": 10,
  "totalItems": 1,
  "totalPages": 1
}
```

### 4.2 Detail produk

```http
GET /api/products/{id}
Authorization: Bearer $TOKEN
```

Respons `200 OK` dengan objek produk, atau `404` bila produk tidak aktif/bukan milik pengguna.

### 4.3 Membuat produk

```http
POST /api/products
Authorization: Bearer $TOKEN
Content-Type: application/json
```

```json
{
  "sku": "KOPI-001",
  "name": "Kopi Arabica 250g",
  "categoryId": "ca1d41c8-facd-4046-94c0-27d51354dd6f",
  "description": "Biji kopi arabica",
  "price": 75000,
  "minStock": 5
}
```

Aturan:

- `sku`: wajib, 1–64 karakter; di-trim dan diubah ke uppercase; unik per pengguna.
- `name`: 2–160 karakter.
- `categoryId`: wajib dan harus milik pengguna yang sama.
- `description`: opsional, maksimal 500 karakter.
- `price`: `>= 0`.
- `minStock`: `>= 0`.
- **Stok awal selalu `0`**; field stok tidak diterima pada create.

Respons `201 Created` dengan objek produk. Error: `400`, `404` kategori tidak ditemukan, `409` SKU duplikat.

### 4.4 Memperbarui produk

```http
PUT /api/products/{id}
Authorization: Bearer $TOKEN
Content-Type: application/json
```

```json
{
  "sku": "KOPI-001",
  "name": "Kopi Arabica Premium 250g",
  "categoryId": "ca1d41c8-facd-4046-94c0-27d51354dd6f",
  "description": "Biji kopi arabica premium",
  "price": 85000,
  "minStock": 8,
  "isActive": true
}
```

`isActive` opsional; bila `null`/tidak dikirim, status aktif tidak berubah. **Endpoint ini tidak mengubah `stockQuantity`.** Stok hanya berubah melalui endpoint movement.

Error: `400`, `404`, `409` SKU duplikat.

### 4.5 Menghapus produk (soft delete)

```http
DELETE /api/products/{id}
Authorization: Bearer $TOKEN
```

Respons `204 No Content`. Produk diubah menjadi `is_active = false`, tidak dihapus fisik. Riwayat stok tetap tersimpan dan masih dapat dibaca melalui endpoint riwayat produk.

## 5. Pergerakan stok

Riwayat bersifat **append-only**; tidak ada endpoint update atau delete.

### 5.1 Mencatat stok masuk/keluar

```http
POST /api/products/{productId}/movements
Authorization: Bearer $TOKEN
Content-Type: application/json
```

```json
{
  "type": "IN",
  "quantity": 10,
  "note": "Stok awal dari pemasok"
}
```

| Field | Aturan |
|---|---|
| `type` | `IN` atau `OUT`. |
| `quantity` | Bilangan bulat > 0. |
| `note` | Opsional, maksimal 300 karakter. |

Respons `201 Created`:

```json
{
  "id": "f3f1c2a1-1111-4222-8333-444455556666",
  "productId": "3b6d9a4e-2f4f-4f3c-9f6f-4a4d6e7f8a90",
  "productSku": "KOPI-001",
  "productName": "Kopi Arabica 250g",
  "type": "IN",
  "quantity": 10,
  "stockBefore": 0,
  "stockAfter": 10,
  "note": "Stok awal dari pemasok",
  "createdAt": "2026-10-24T10:03:00+00:00"
}
```

Perilaku penting:

- Update `products.stock_quantity` dan insert `stock_movements` dilakukan dalam satu transaksi database.
- Produk di-lock dengan `SELECT ... FOR UPDATE` untuk mencegah race condition.
- `OUT` yang melebihi stok tersedia menghasilkan `409 Conflict` dan **tidak** membuat riwayat.
- Produk nonaktif/tidak ditemukan/bukan milik pengguna menghasilkan `404`.
- `quantity` nol/negatif atau tipe selain `IN`/`OUT` menghasilkan `400`.

### 5.2 Riwayat per produk

```http
GET /api/products/{productId}/movements?page=1&pageSize=20
Authorization: Bearer $TOKEN
```

Respons `200 OK`:

```json
{
  "items": [
    {
      "id": "f3f1c2a1-1111-4222-8333-444455556666",
      "productId": "3b6d9a4e-2f4f-4f3c-9f6f-4a4d6e7f8a90",
      "productSku": "KOPI-001",
      "productName": "Kopi Arabica 250g",
      "type": "IN",
      "quantity": 10,
      "stockBefore": 0,
      "stockAfter": 10,
      "note": "Stok awal dari pemasok",
      "createdAt": "2026-10-24T10:03:00+00:00"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "totalItems": 1,
  "totalPages": 1
}
```

Riwayat tetap dapat dibaca untuk produk yang sudah soft-deleted, selama produk tersebut milik pengguna.

### 5.3 Riwayat seluruh produk

```http
GET /api/stock-movements?page=1&pageSize=20
Authorization: Bearer $TOKEN
```

Respons sama dengan riwayat per produk, berisi seluruh movement milik pengguna.

## 6. Dashboard

```http
GET /api/dashboard/summary
Authorization: Bearer $TOKEN
```

Respons `200 OK`:

```json
{
  "activeProducts": 2,
  "categories": 1,
  "totalStockUnits": 12,
  "lowStockProducts": 1,
  "lowStockItems": [
    {
      "id": "3b6d9a4e-2f4f-4f3c-9f6f-4a4d6e7f8a90",
      "sku": "LOW-001",
      "name": "Produk Stok Rendah",
      "stockQuantity": 2,
      "minStock": 5
    }
  ]
}
```

`lowStockItems` dibatasi maksimal 10 item untuk preview. `lowStockProducts` menghitung seluruh produk aktif yang memenuhi `stock_quantity <= min_stock`.

## 7. Health check

```http
GET /health
```

Tidak memerlukan token. Contoh respons sehat:

```json
{
  "status": "Healthy",
  "checks": [
    {
      "name": "database",
      "status": "Healthy",
      "description": "Database dapat diakses."
    }
  ],
  "totalDurationMs": 12.3
}
```

Bila database tidak dapat diakses, status HTTP `503` dan status check `Unhealthy`.

## 8. Contoh alur curl

```bash
# 1. Register
curl -s -X POST "$API_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Budi Santoso","email":"budi@example.com","password":"Password123!"}'

# 2. Login dan salin accessToken ke variabel TOKEN
curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"budi@example.com","password":"Password123!"}'

# 3. Buat kategori
curl -s -X POST "$API_URL/api/categories" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Minuman"}'

# 4. Buat produk (stok awal 0)
curl -s -X POST "$API_URL/api/products" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"sku":"KOPI-001","name":"Kopi Arabica","categoryId":"<uuid-kategori>","price":75000,"minStock":5}'

# 5. Stok masuk 10
curl -s -X POST "$API_URL/api/products/<uuid-produk>/movements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"IN","quantity":10,"note":"Stok awal"}'

# 6. Stok keluar 3
curl -s -X POST "$API_URL/api/products/<uuid-produk>/movements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"OUT","quantity":3,"note":"Penjualan"}'

# 7. Dashboard
curl -s "$API_URL/api/dashboard/summary" \
  -H "Authorization: Bearer $TOKEN"

# 8. Riwayat semua movement
curl -s "$API_URL/api/stock-movements?page=1&pageSize=20" \
  -H "Authorization: Bearer $TOKEN"
```

## 9. Catatan implementasi

- Semua query memakai parameter Dapper; tidak ada string SQL yang digabung dengan input pengguna.
- `user_id` tidak pernah dibaca dari body/query. Nilai diambil dari klaim JWT `sub`.
- Composite foreign key di database membantu memastikan produk hanya memakai kategori milik pengguna yang sama dan movement hanya dibuat oleh pemilik produk.
- Semua timestamp menggunakan `TIMESTAMPTZ` dan dikirim sebagai ISO-8601.
- Swagger tersedia di `/swagger` saat environment Development atau `Swagger__Enabled=true`.
