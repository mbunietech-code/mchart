import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/app_notification.dart';
import '../auth/auth_controller.dart';

class NotificationsState {
  const NotificationsState({this.items = const [], this.loading = true});
  final List<AppNotification> items;
  final bool loading;

  int get unread => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({List<AppNotification>? items, bool? loading}) =>
      NotificationsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
      );
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref) : super(const NotificationsState()) {
    _load();
    _subscribe();
  }

  final Ref _ref;
  VoidCallback? _unsub;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> _load() async {
    try {
      final json = await _api.get<Map<String, dynamic>>(
        '/notifications',
        query: {'per_page': 40},
      );
      final items = (json['data'] as List? ?? const [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(items: items, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void _subscribe() {
    final me = _ref.read(currentUserProvider);
    if (me == null) return;
    final rt = _ref.read(realtimeClientProvider)..connect();
    _unsub = rt.on('private-user.${me.id}', 'notification.created', (data) {
      final n = AppNotification.fromJson(data);
      if (state.items.any((e) => e.id == n.id)) return;
      state = state.copyWith(items: [n, ...state.items]);
    });
  }

  Future<void> refresh() => _load();

  Future<void> markRead(int id) async {
    state = state.copyWith(
      items: [
        for (final n in state.items) n.id == id ? n.copyWith(isRead: true) : n,
      ],
    );
    try {
      await _api.post('/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      items: [for (final n in state.items) n.copyWith(isRead: true)],
    );
    try {
      await _api.post('/notifications/read-all');
    } catch (_) {}
  }

  @override
  void dispose() {
    _unsub?.call();
    super.dispose();
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
      return NotificationsController(ref);
    });
