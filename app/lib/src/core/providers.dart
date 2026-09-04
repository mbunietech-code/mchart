import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'realtime.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});

/// A bare Dio pre-configured with the bearer token, used by the realtime
/// client for the /broadcasting/auth handshake.
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final authDio = Dio(BaseOptions(headers: {'Accept': 'application/json'}))
    ..interceptors.add(
      InterceptorsWrapper(onRequest: (o, h) {
        final t = tokens.value;
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      }),
    );
  final client = RealtimeClient(authDio: authDio);
  ref.onDispose(client.dispose);
  return client;
});

/// Reactive view of the realtime socket connection state.
final realtimeConnectedProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(realtimeClientProvider);
  final controller = StreamController<bool>();
  void emit() => controller.add(client.connected.value);
  client.connected.addListener(emit);
  emit();
  ref.onDispose(() {
    client.connected.removeListener(emit);
    controller.close();
  });
  return controller.stream;
});
