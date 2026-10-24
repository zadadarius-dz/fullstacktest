import '../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<AuthSession> login(String email, String password) async {
    final response = await _client.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response as Map<String, dynamic>);
  }

  Future<AuthSession> register(String name, String email, String password) async {
    final response = await _client.post(
      '/api/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthSession.fromJson(response as Map<String, dynamic>);
  }

  Future<User> me() async {
    final response = await _client.get('/api/auth/me');
    return User.fromJson(response as Map<String, dynamic>);
  }
}
