import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockState {
  const AppLockState({
    this.ready = false,
    this.hasPin = false,
    this.locked = false,
  });
  final bool ready;
  final bool hasPin;
  final bool locked;
}

/// Optional PIN set from the profile page. Once set, MChat asks for it every
/// time it starts, and when it comes back after more than [_grace] in the
/// background. Only a salted hash is kept, in the OS secure store.
class AppLock extends StateNotifier<AppLockState> with WidgetsBindingObserver {
  AppLock([FlutterSecureStorage? storage])
    // macOS: the legacy keychain needs no keychain-access-groups
    // entitlement / provisioning profile (ad-hoc or Developer ID builds).
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          ),
      super(const AppLockState()) {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  static const _key = 'mchart.pin';
  // Short trips out (camera, file picker, a quick app switch) don't lock.
  static const _grace = Duration(seconds: 30);

  final FlutterSecureStorage _storage;
  String? _stored; // "salt:hash"
  DateTime? _leftAt;

  Future<void> _load() async {
    try {
      _stored = await _storage.read(key: _key);
    } catch (e) {
      debugPrint('AppLock: could not read PIN: $e');
    }
    if (!mounted) return;
    final has = _stored != null;
    state = AppLockState(ready: true, hasPin: has, locked: has);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!state.hasPin) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && DateTime.now().difference(left) > _grace) {
        state = AppLockState(ready: true, hasPin: true, locked: true);
      }
    }
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Unlocks when [pin] matches; returns whether it did.
  bool unlock(String pin) {
    final stored = _stored;
    if (stored == null) return true;
    final i = stored.indexOf(':');
    if (_hash(stored.substring(0, i), pin) != stored.substring(i + 1)) {
      return false;
    }
    state = const AppLockState(ready: true, hasPin: true);
    return true;
  }

  bool matches(String pin) {
    final stored = _stored;
    if (stored == null) return false;
    final i = stored.indexOf(':');
    return _hash(stored.substring(0, i), pin) == stored.substring(i + 1);
  }

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List.generate(16, (_) => rnd.nextInt(256)));
    _stored = '$salt:${_hash(salt, pin)}';
    await _storage.write(key: _key, value: _stored);
    state = const AppLockState(ready: true, hasPin: true);
  }

  /// Also used on sign-out, so the next person on this device isn't held
  /// behind someone else's PIN.
  Future<void> clearPin() async {
    _stored = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    if (mounted) state = const AppLockState(ready: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final appLockProvider = StateNotifierProvider<AppLock, AppLockState>(
  (ref) => AppLock(),
);
