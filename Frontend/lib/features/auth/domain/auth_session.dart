import '../../../core/storage/token_store.dart';
import 'user_profile.dart';

class AuthSession {
  const AuthSession({
    required this.tokens,
    required this.tokenType,
    required this.user,
  });

  final AuthTokens tokens;
  final String tokenType;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final int expiresIn = (json['expires_in'] as num?)?.toInt() ?? 0;
    return AuthSession(
      tokens: AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      ),
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: UserProfile.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
    );
  }
}
