# StockMate Mobile

Aplikasi Android untuk **StockMate — Simple Inventory Management System**, dibangun dengan Flutter dan terhubung ke StockMate REST API yang sama dengan web.

> **Status verifikasi: BELUM DI-BUILD.** Flutter/Dart dan Android SDK **tidak terpasang** di mesin pengembangan. Kode sudah ditulis lengkap, tetapi `flutter pub get`, `flutter analyze`, dan `flutter build apk` **belum pernah dijalankan**. Tidak ada APK yang dihasilkan. Lihat [`../stockmate/docs/TESTING.md`](../stockmate/docs/TESTING.md).

## 1. Fitur

- Register dan login dengan JWT.
- Token disimpan di **flutter_secure_storage** (Android Keystore), bukan `SharedPreferences`.
- Sesi dipulihkan saat aplikasi dibuka kembali.
- Dashboard ringkasan inventaris.
- Daftar produk dengan pencarian, filter kategori, filter stok menipis, dan pagination.
- Detail produk dengan informasi lengkap.
- Form produk create/edit; stok awal 0 dan edit tidak mengubah stok.
- Pembuatan kategori cepat dari dalam form produk.
- Pencatatan transaksi stok `IN`/`OUT` dari detail produk.
- Riwayat stok per produk dan seluruh produk.
- Soft delete produk.
- State loading, empty, error, dan sukses.
- Sesi kedaluwarsa (`401`) otomatis keluar ke halaman login.
- UI berbahasa Indonesia, format Rupiah dan tanggal `id_ID`.

## 2. Stack

| Komponen | Versi |
|---|---|
| Flutter SDK | `>=3.4.0 <4.0.0` (dideklarasikan; belum diverifikasi) |
| provider | ^6.1.2 |
| http | ^1.2.2 |
| flutter_secure_storage | ^9.2.2 |
| intl | ^0.19.0 |
| cupertino_icons | ^1.0.8 |
| flutter_lints | ^4.0.0 |

State management memakai **Provider** (`ChangeNotifier`). HTTP memakai package `http`. Tidak ada code generation.

## 3. Prasyarat

- Flutter SDK stabil yang memenuhi constraint SDK.
- Android SDK, build tools, dan JDK yang kompatibel.
- Emulator Android atau perangkat fisik.
- Backend StockMate berjalan dan dapat diakses dari perangkat/emulator.

## 4. Struktur proyek

```text
lib/
  main.dart                     Entry point, MultiProvider, MaterialApp
  core/
    config/app_config.dart      API base URL + timeout
    network/api_client.dart     HTTP client, bearer token, error mapping
    network/api_exception.dart  ApiException
    theme/app_theme.dart        Warna dan tema Material 3
    utils/formatters.dart       Rupiah, angka, tanggal
  models/                       auth_session, user, category, product,
                                stock_movement, dashboard_summary, paged_result
  providers/                    auth, category, product, movement, dashboard
  screens/
    auth/                       auth_gate, login, register
    home/home_shell.dart        Bottom navigation
    dashboard/                  Dashboard
    products/                   list, detail, form
    movements/                  Riwayat seluruh stok
  services/                     auth, category, product, movement, dashboard,
                                token_storage
  widgets/                      async_state, section_card, badges
pubspec.yaml
analysis_options.yaml
```

Folder `android/`, `ios/`, dan file platform lain **belum ada**.

## 5. Menyiapkan platform folder

Karena repository ini hanya berisi kode Dart, folder platform harus dibuat:

```bash
cd C:\Projects\stockmate-mobile
flutter create --platforms=android,ios .
```

> **Penting:** `flutter create` dapat menambahkan atau menimpa file. Lakukan commit terlebih dahulu, lalu tinjau `git diff`. Pastikan `lib/`, `pubspec.yaml`, dan `analysis_options.yaml` tetap sesuai.

Setelah itu:

```bash
flutter pub get
flutter analyze
```

## 6. Menjalankan aplikasi

### 6.1 Android emulator

Default API URL adalah `http://10.0.2.2:5131`, yaitu alias loopback host dari emulator Android.

```bash
# Backend harus listen pada port yang dapat dijangkau emulator
cd C:\projects\stockmate
dotnet run --project StockMate.Api
```

Lalu:

```bash
cd C:\Projects\stockmate-mobile
flutter run
```

### 6.2 Perangkat fisik

`10.0.2.2` **tidak berlaku** untuk perangkat fisik. Gunakan IP LAN komputer yang menjalankan API:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5131
```

Pastikan:

- API listen pada antarmuka yang dapat dijangkau (`ASPNETCORE_URLS=http://0.0.0.0:5131`).
- Firewall mengizinkan port tersebut.
- Perangkat dan komputer berada di jaringan yang sama.

Untuk build rilis, gunakan HTTPS:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<domain-api-anda>
```

### 6.3 Override URL API

`API_BASE_URL` dibaca melalui `String.fromEnvironment` di `lib/core/config/app_config.dart`. Nilai harus diberikan saat `flutter run`/`flutter build`; mengubahnya setelah build tidak berpengaruh.

## 7. Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<domain-api-anda>
```

Output yang diharapkan:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Untuk Play Store:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<domain-api-anda>
```

Konfigurasi signing produksi (keystore, `key.properties`) **tidak** disertakan dan tidak boleh di-commit.

### Status build

| Item | Status |
|---|---|
| `flutter pub get` | Belum dijalankan |
| `flutter analyze` | Belum dijalankan |
| `flutter test` | Belum ada test; belum dijalankan |
| APK release | **Belum dibangun** |
| Lokasi APK | `build/app/outputs/flutter-apk/app-release.apk` (setelah build berhasil) |

## 8. Keamanan

- Token akses disimpan melalui `flutter_secure_storage`, yang memakai Android Keystore/EncryptedSharedPreferences.
- Token tidak ditulis ke log.
- Logout menghapus token dari secure storage.
- Respons `401` memicu `onUnauthorized` dan mengembalikan pengguna ke login.
- Untuk produksi, **wajib HTTPS**; jangan mengirim token melalui HTTP biasa.
- Tidak ada credential yang ditanam di kode.
- `usesCleartextTraffic` untuk HTTP lokal hanya boleh dipakai di development; jangan aktifkan di rilis.

## 9. Alur data

```text
Screen → Provider (ChangeNotifier) → Service → ApiClient → REST API
                                      │
                                      └─ TokenStorage (secure storage)
```

- Provider menyimpan state dan memanggil `notifyListeners()`.
- Service memetakan JSON ke model.
- `ApiClient` menambahkan bearer token, menangani timeout, dan mengubah error menjadi `ApiException` dengan pesan yang dapat ditampilkan.
- `AuthProvider.handleUnauthorized()` dipanggil saat API mengembalikan `401`.

## 10. Troubleshooting

| Gejala | Penyebab | Tindakan |
|---|---|---|
| `SocketException` / connection refused | API mati atau URL salah | Jalankan backend; periksa `API_BASE_URL`. |
| Emulator tidak dapat terhubung | Memakai `localhost` | Gunakan `10.0.2.2` untuk emulator. |
| Perangkat fisik tidak terhubung | Memakai `10.0.2.2` atau firewall | Gunakan IP LAN; buka port; cek firewall. |
| `Cleartext HTTP not permitted` | Android memblokir HTTP | Gunakan HTTPS, atau konfigurasi network security khusus development. |
| Login berhasil lalu keluar sendiri | Token kedaluwarsa / signing key berubah | Login ulang; pastikan key API stabil. |
| `flutter pub get` gagal | SDK tidak sesuai | Periksa `flutter --version` terhadap constraint `>=3.4.0 <4.0.0`. |
| Build gagal setelah `flutter create` | File platform tertimpa | Tinjau `git diff`, pulihkan file yang salah. |

## 11. Yang belum ada

- Test widget/unit.
- Build dan verifikasi APK.
- CI/CD.
- Deep link, notifikasi, mode offline.
- Dukungan iOS yang telah diuji (folder iOS belum dibuat).
- Publikasi ke Play Store.

Semua item di atas adalah pekerjaan lanjutan dan **belum** diselesaikan.
