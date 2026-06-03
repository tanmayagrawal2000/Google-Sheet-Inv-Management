import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the serialized OAuth credentials (access + refresh token JSON) in
/// platform-secure storage: DPAPI on Windows, Keychain on iOS/macOS, Keystore
/// on Android. Wired into [GoogleSignInParams] save/retrieve/delete callbacks.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'google_credentials';

  final FlutterSecureStorage _storage;

  Future<void> save(String value) => _storage.write(key: _key, value: value);

  Future<String?> retrieve() => _storage.read(key: _key);

  Future<void> delete() => _storage.delete(key: _key);
}
