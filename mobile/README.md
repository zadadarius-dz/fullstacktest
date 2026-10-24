# StockMate Mobile

Aplikasi Android untuk **StockMate — Simple Inventory Management System**, dibangun dengan Flutter dan terhubung ke StockMate REST API yang sama dengan web.

> **Status verifikasi: SUDAH DI-BUILD DAN DIUJI DI HP.** Flutter 3.47.8, `flutter analyze` bersih (0 issue), `flutter test` 5/5 lulus, dan APK release 50,0 MB berhasil dibangun, diinstal, serta dijalankan di HP Android 14 (2410FPCC5G) melalui `adb reverse`. Login, dashboard, produk, kategori, dan riwayat berhasil memanggil API. Lihat [`../docs/TESTING.md`](../docs/TESTING.md).

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
| Flutter SDK | 3.47.8 stable (Dart 3.13.7) — terverifikasi |
| provider | ^6.1.2 |
| http | ^1.2.2 |
| flutter_secure_storage | ^9.2.2 (terpasang 9.2.4) |
| intl | ^0.19.0 |
| cupertino_icons | ^1.0.8 |
| flutter_lints | ^4.0.0 |

State management memakai **Provider** (`ChangeNotifier`). HTTP memakai package `http`. Tidak ada code generation.

## 3. Prasyarat

- Flutter SDK stabil yang memenuhi constraint SDK (diuji dengan 3.47.8).
- Android SDK 36, build tools, dan JDK 17 (diuji dengan JDK bawaan Android Studio).
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
android/                      Proyek Android (applicationId com.stockmate.stockmate_mobile)
ios/                          Proyek iOS
test/widget_test.dart         Test formatter dan widget dasar
```

Folder `android/` dan `ios/` sudah dibuat dengan `flutter create` dan ikut di-commit. Folder `build/`, `.dart_tool/`, serta artefak Gradle tidak di-commit.

## 5. Platform Android dan iOS

Folder platform sudah tersedia, jadi tidak perlu menjalankan `flutter create` lagi. Jika perlu meregenerasi:

```bash
cd C:\projects\stockmate\mobile
flutter create --platforms=android,ios --org com.stockmate --project-name stockmate_mobile .
```

> **Penting:** `flutter create` dapat menambahkan atau menimpa file. Lakukan commit terlebih dahulu, lalu tinjau `git diff`. Pastikan `lib/`, `pubspec.yaml`, `analysis_options.yaml`, dan `android/app/src/main/AndroidManifest.xml` tetap sesuai.

Konfigurasi Android yang sudah diterapkan:

- `INTERNET` permission di `android/app/src/main/AndroidManifest.xml`.
- Label aplikasi `StockMate`.
- `android/app/src/main/res/xml/network_security_config.xml`: cleartext HTTP **hanya** untuk `10.0.2.2`, `localhost`, dan `127.0.0.1`. Domain lain wajib HTTPS.
- `minSdk` mengikuti default Flutter (24), cocok untuk `flutter_secure_storage`.

Setelah perubahan dependensi:

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
cd C:\projects\stockmate\mobile
flutter run
```

### 6.2 Perangkat fisik

#### Cara mudah: USB + `adb reverse` (dipakai saat verifikasi)

Cara ini tidak memerlukan IP LAN, firewall, atau perubahan alamat listen API.

```powershell
# HP terhubung USB dan USB debugging aktif
adb reverse tcp:5131 tcp:5131

flutter build apk --release --dart-define=API_BASE_URL=http://127.0.0.1:5131
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

`adb reverse` membuat `127.0.0.1:5131` di HP diteruskan ke `127.0.0.1:5131` di komputer. Mapping ini **hilang** saat kabel dilepas, adb server restart, atau HP reboot; jalankan ulang `adb reverse` sebelum membuka aplikasi.

Jika HP menolak instalasi dengan `INSTALL_FAILED_USER_RESTRICTED`, aktifkan **Developer options → Install via USB** (Xiaomi/HyperOS) atau opsi serupa pada merek lain.

#### Cara alternatif: Wi-Fi / LAN

`10.0.2.2` **tidak berlaku** untuk perangkat fisik. Gunakan IP LAN komputer yang menjalankan API:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5131
```

Pastikan:

- API listen pada antarmuka yang dapat dijangkau (`ASPNETCORE_URLS=http://0.0.0.0:5131`).
- Firewall mengizinkan port tersebut.
- Perangkat dan komputer berada di jaringan yang sama.
- Untuk HTTP di perangkat fisik, tambahkan IP LAN komputer ke `android/app/src/main/res/xml/network_security_config.xml`, misalnya `<domain includeSubdomains="false">192.168.1.10</domain>`, lalu build ulang. Tanpa itu Android memblokir cleartext HTTP.

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
| `flutter pub get` | ✅ Berhasil (Flutter 3.47.8 / Dart 3.13.7) |
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **5/5 lulus** (formatter + widget) |
| APK release | ✅ Berhasil, **50,0 MB** |
| Lokasi APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Instalasi & runtime | ✅ Terpasang dan berjalan di 2410FPCC5G (Android 14) |
| Koneksi API | ✅ Login + dashboard + produk + kategori + riwayat, semua HTTP 200 |

APK verifikasi dibangun dengan `--dart-define=API_BASE_URL=http://127.0.0.1:5131` dan memerlukan `adb reverse tcp:5131 tcp:5131`. APK ini ditandatangani dengan **debug key** dari template Flutter; bukan untuk Play Store.

## 8. Keamanan

- Token akses disimpan melalui `flutter_secure_storage` yang memakai Android Keystore.
- Token tidak ditulis ke log.
- Logout menghapus token dari secure storage.
- Respons `401` memicu `onUnauthorized` dan mengembalikan pengguna ke login.
- Untuk produksi, **wajib HTTPS**; jangan mengirim token melalui HTTP biasa.
- Tidak ada credential yang ditanam di kode.
- `usesCleartextTraffic` tidak diaktifkan secara global. Cleartext hanya diizinkan untuk alamat loopback pengembangan melalui `network_security_config.xml`; domain lain wajib HTTPS.

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
| `Cleartext HTTP not permitted` | Android memblokir HTTP | Tambahkan host/IP ke `network_security_config.xml`, atau gunakan HTTPS. |
| Login berhasil lalu keluar sendiri | Token kedaluwarsa / signing key berubah | Login ulang; pastikan key API stabil. |
| `flutter pub get` gagal | SDK tidak sesuai | Periksa `flutter --version` terhadap constraint `>=3.4.0 <4.0.0`. |
| Build gagal setelah `flutter create` | File platform tertimpa | Tinjau `git diff`, pulihkan file yang salah. |

## 11. Yang belum ada

- Uji manual lengkap seluruh alur (create/edit produk, transaksi IN/OUT, soft delete, sesi kedaluwarsa). Yang sudah diverifikasi: login, dashboard, daftar produk, kategori, dan riwayat.
- CI/CD.
- Deep link, notifikasi, mode offline.
- Dukungan iOS yang telah diuji di macOS.
- Publikasi ke Play Store dan signing produksi.

Semua item di atas adalah pekerjaan lanjutan dan **belum** diselesaikan.
