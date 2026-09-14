import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the refresh token in platform-secure storage (Keychain / Keystore).
/// The short-lived access token is held in memory only (see [DioClient]).
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _refreshKey = 'refresh_token';
  static const _accessKey = 'auth_token'; // mirrored for cold-start reuse

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});
