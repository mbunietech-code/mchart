import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';

import '../models/app_notification.dart';

/// Windows toasts. FCM doesn't reach desktop, so new notifications that
/// arrive while the app runs (realtime or polling) pop a toast whenever the
/// MChart window isn't the one in front.
class DesktopNotifier {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> init() async {
    if (!supported) return;
    try {
      await localNotifier.setup(
        appName: 'MChart',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } catch (e) {
      debugPrint('Desktop notifications unavailable: $e');
    }
  }

  static void show(AppNotification n) {
    if (!supported) return;
    // Window in front: the bell and badges already show it.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    LocalNotification(title: n.title, body: n.body ?? '').show();
  }
}
