import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required TokenStorage tokenStorage,
    required ApiClient apiClient,
  })  : _tokenStorage = tokenStorage,
        _authService = AuthService(apiClient);

  final TokenStorage _tokenStorage;
  final AuthService _authService;

  User? _user;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isReady => _ready;
  bool get isBusy => _busy;
  String? get error => _error;

  Future<void> initialize() async {
    if (_ready) return;

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      _user = await _authService.me();
    } on ApiException {
      await _tokenStorage.clearToken();
      _user = null;
    } catch (_) {
      await _tokenStorage.clearToken();
      _user = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authService.login(email.trim(), password);
      await _tokenStorage.writeToken(session.accessToken);
      _user = session.user;
      return true;
    } on ApiException catch (exception) {
      _error = exception.message;
      return false;
    } catch (_) {
      _error = 'Terjadi kesalahan saat login.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authService.register(
        name.trim(),
        email.trim(),
        password,
      );
      await _tokenStorage.writeToken(session.accessToken);
      _user = session.user;
      return true;
    } on ApiException catch (exception) {
      _error = exception.message;
      return false;
    } catch (_) {
      _error = 'Terjadi kesalahan saat mendaftar.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void handleUnauthorized() {
    _user = null;
    _error = 'Sesi berakhir. Silakan login kembali.';
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
