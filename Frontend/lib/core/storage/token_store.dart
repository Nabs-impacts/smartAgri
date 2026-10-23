import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

class TokenStore {
  TokenStore({TokenStorage? storage})
    : _storage = storage ?? SecureTokenStorage();

  static const String accessKey = 'access_token';
  static const String refreshKey = 'refresh_token';
  static const String expiresAtKey = 'expires_at';

  final TokenStorage _storage;
  AuthTokens? _memory;
  bool _persistent = false;

  bool get isPersistent => _persistent;

  Future<void> save(
    String access,
    String refresh,
    int expiresIn, {
    required bool remember,
  }) async {
    final AuthTokens tokens = AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
    _memory = tokens;
    _persistent = remember;
    if (remember) {
      await _storage.write(accessKey, tokens.accessToken);
      await _storage.write(refreshKey, tokens.refreshToken);
      await _storage.write(expiresAtKey, tokens.expiresAt.toIso8601String());
    } else {
      await _deletePersisted();
    }
  }

  Future<AuthTokens?> read() async {
    if (_memory != null) {
      return _memory;
    }
    final String? access = await _storage.read(accessKey);
    final String? refresh = await _storage.read(refreshKey);
    if (access == null || refresh == null) {
      return null;
    }
    final String? expiresAtRaw = await _storage.read(expiresAtKey);
    final DateTime expiresAt =
        DateTime.tryParse(expiresAtRaw ?? '') ?? DateTime.now();
    final AuthTokens tokens = AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
    );
    _memory = tokens;
    _persistent = true;
    return tokens;
  }

  Future<void> clear() async {
    _memory = null;
    _persistent = false;
    await _deletePersisted();
  }

  Future<void> _deletePersisted() async {
    await _storage.delete(accessKey);
    await _storage.delete(refreshKey);
    await _storage.delete(expiresAtKey);
  }
}

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => TokenStore(),
);
