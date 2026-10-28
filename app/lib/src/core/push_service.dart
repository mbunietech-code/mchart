import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_router.dart';
import '../features/chat/chat_repository.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/status/announcement_repository.dart';
import 'providers.dart';

/// Shows foreground pushes as a snackbar from anywhere in the app.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Firebase Cloud Messaging: Android only (the Firebase config is
/// google-services.json). While the app is closed or in the background,
/// Android itself shows the notification on the high-importance channel
/// MainActivity creates; this class handles registration, foreground
/// messages and taps.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool _firebaseReady = false;

  /// This phone's FCM token, sent with logout so the server forgets it.
  static String? currentToken;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Call once from main(); a missing/invalid config only disables push.
  static Future<void> initFirebase() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('[push] Firebase init failed, push disabled: $e');
    }
  }

  /// After sign-in: ask permission (Android 13+), register this phone with
  /// the server, and start listening.
  Future<void> start() async {
    if (!_firebaseReady || _subs.isNotEmpty) return;
    final fcm = FirebaseMessaging.instance;
    try {
      final settings = await fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] notifications denied by the user');
      }
      currentToken = await fcm.getToken();
      if (currentToken != null) await _register(currentToken!);
    } catch (e) {
      debugPrint('[push] registration failed: $e');
    }

    _subs
      ..add(
        fcm.onTokenRefresh.listen((t) {
          currentToken = t;
          unawaited(_register(t));
        }),
      )
      ..add(FirebaseMessaging.onMessage.listen(_onForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open));

    // Opened by tapping a notification while the app was closed.
    final initial = await fcm.getInitialMessage();
    if (initial != null) _open(initial);
  }

  /// After sign-out. The server already dropped this phone's token
  /// (logout sends it), so only local listeners need stopping.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  Future<void> _register(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post(
            '/devices',
            data: {
              'platform': 'android',
              'push_token': token,
              'device_name': 'Android phone',
            },
          );
    } catch (e) {
      debugPrint('[push] could not register device: $e');
    }
  }

  void _onForeground(RemoteMessage m) {
    _refreshFor(m.data);
    final title = m.notification?.title;
    if (title == null) return;
    // Already looking at that chat: the thread shows it, no banner needed.
    final router = _ref.read(routerProvider);
    final here = router.state.uri.toString();
    final convo = m.data['conversation_id'];
    if (convo != null && here.contains('c=$convo')) return;

    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          m.notification?.body == null
              ? title
              : '$title\n${m.notification!.body}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        action: _routeFor(m.data) == null
            ? null
            : SnackBarAction(label: 'Open', onPressed: () => _open(m)),
      ),
    );
  }

  void _open(RemoteMessage m) {
    _refreshFor(m.data);
    final route = _routeFor(m.data);
    if (route != null) _ref.read(routerProvider).go(route);
  }

  /// Same targets as tapping an item in the notifications panel.
  static String? _routeFor(Map<String, dynamic> d) {
    if (d['conversation_id'] != null) return '/chats?c=${d['conversation_id']}';
    if (d['task_id'] != null) return '/tasks/${d['task_id']}';
    if (d['type'] == 'announcement') return '/status';
    return null;
  }

  void _refreshFor(Map<String, dynamic> d) {
    unawaited(_ref.read(notificationsControllerProvider.notifier).refresh());
    if (d['conversation_id'] != null) _ref.invalidate(conversationsProvider);
    if (d['type'] == 'announcement') {
      _ref.invalidate(announcementUnreadProvider);
      _ref.invalidate(announcementsProvider);
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
