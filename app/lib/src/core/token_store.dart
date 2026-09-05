import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token in the OS keychain / credential store.
///
/// Persistence is best-effort: `_cached` is always updated first, so a
/// storage failure (e.g. flutter_secure_storage's web backend refusing to
/// write in some hosting/browser configurations) degrades to an in-memory
/// session — the user stays signed in for this run but is asked to log in
/// again after a full page reload — rather than aborting the sign-in.
class TokenStore {
  // flutter_secure_storage 11's default AndroidOptions() already uses
  // AES-GCM with RSA OAEP key wrapping — stronger than the old
  // encryptedSharedPreferences flag this replaced, so no options needed.
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'mchart.token';
  final FlutterSecureStorage _storage;

  String? _cached;
  String? get value => _cached;

  Future<String?> load() async {
    try {
      _cached = await _storage.read(key: _key);
    } catch (e) {
      debugPrint('TokenStore.load failed, starting signed out: $e');
      _cached = null;
    }
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    try {
      await _storage.write(key: _key, value: token);
    } catch (e) {
      debugPrint(
        'TokenStore.save failed; continuing with an in-memory session: $e',
      );
    }
  }

  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('TokenStore.clear failed: $e');
    }
  }
}
