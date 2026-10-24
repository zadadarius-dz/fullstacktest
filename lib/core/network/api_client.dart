import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../services/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    this.onUnauthorized,
    http.Client? client,
    String? baseUrl,
  })  : _tokenStorage = tokenStorage,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.normalizedApiBaseUrl;

  final TokenStorage _tokenStorage;
  final http.Client _client;
  final String _baseUrl;
  final void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    final merged = <String, String>{...base.queryParameters};
    if (query != null) {
      query.forEach((key, value) {
        if (value != null && value.isNotEmpty) {
          merged[key] = value;
        }
      });
    }
    return base.replace(queryParameters: merged.isEmpty ? null : merged);
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Map<String, dynamic>? body,
  }) async {
    final token = await _tokenStorage.readToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final uri = _uri(path, query);
      final encodedBody = body == null ? null : jsonEncode(body);
      final Future<http.Response> requestFuture = switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      };
      response = await requestFuture.timeout(AppConfig.requestTimeout);
    } on Exception {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi dan API_BASE_URL.',
      );
    }

    if (response.statusCode == 401) {
      await _tokenStorage.clearToken();
      onUnauthorized?.call();
      throw ApiException(
        'Sesi berakhir. Silakan login kembali.',
        statusCode: 401,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } on FormatException {
        return null;
      }
    }

    throw _parseError(response);
  }

  ApiException _parseError(http.Response response) {
    String? message;
    Map<String, List<String>>? errors;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawErrors = decoded['errors'];
        if (rawErrors is Map<String, dynamic>) {
          errors = <String, List<String>>{};
          rawErrors.forEach((key, value) {
            if (value is List) {
              errors![key] = value.map((item) => item.toString()).toList();
            }
          });
          if (errors!.isNotEmpty) {
            final firstMessages = errors!.values.first;
            if (firstMessages.isNotEmpty) {
              message = firstMessages.first;
            }
          }
        }
        message ??= decoded['detail']?.toString();
        message ??= decoded['title']?.toString();
      }
    } on FormatException {
      // Body bukan JSON; gunakan pesan generik.
    }

    return ApiException(
      message ?? 'Permintaan gagal (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
      errors: errors,
    );
  }
}
