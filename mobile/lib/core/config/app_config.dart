class AppConfig {
  AppConfig._();

  /// Base URL API. Wajib di-override untuk perangkat fisik dan build release:
  /// flutter run --dart-define=API_BASE_URL=https://api.contoh.com
  ///
  /// Default 10.0.2.2 hanya untuk Android emulator (localhost emulator bukan
  /// komputer host). Jangan memakai localhost untuk perangkat fisik.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5131',
  );

  static String get normalizedApiBaseUrl {
    var value = apiBaseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static const Duration requestTimeout = Duration(seconds: 20);
}
