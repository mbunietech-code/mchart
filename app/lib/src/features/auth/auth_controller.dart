import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../core/token_store.dart';
import '../../models/user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.message});
  final String? message;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._tokens) : super(const AuthUnknown()) {
    _api.onUnauthorized = () {
      _tokens.clear();
      if (mounted) state = const Unauthenticated(message: 'Your session has expired.');
    };
  }

  final ApiClient _api;
  final TokenStore _tokens;

  Future<void> bootstrap() async {
    try {
      final token = await _tokens.load();
      if (token == null) {
        state = const Unauthenticated();
        return;
      }
      final json = await _api.get<Map<String, dynamic>>('/me');
      state = Authenticated(User.fromJson(json['data'] as Map<String, dynamic>));
    } catch (_) {
      try {
        await _tokens.clear();
      } catch (_) {}
      state = const Unauthenticated();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    state = const AuthLoading();
    try {
      final json = await _api.post<Map<String, dynamic>>('/auth/login', data: {
        'email': email,
        'password': password,
        if (deviceName != null) 'device_name': deviceName,
      });
      await _tokens.save(json['token'] as String);
      state = Authenticated(User.fromJson(json['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      state = Unauthenticated(message: e.isValidation
          ? (e.firstErrorFor('email') ?? e.message)
          : e.message);
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _api.post('/auth/password/forgot', data: {'email': email});
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _tokens.clear();
    state = const Unauthenticated();
  }

  void updateUser(User user) {
    if (state is Authenticated) state = Authenticated(user);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider));
});

final currentUserProvider = Provider<User?>((ref) {
  final s = ref.watch(authControllerProvider);
  return s is Authenticated ? s.user : null;
});
