import 'user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken']?.toString() ?? '',
        tokenType: json['tokenType']?.toString() ?? 'Bearer',
        expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
        user: User.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
        ),
      );
}
