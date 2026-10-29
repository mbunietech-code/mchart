import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push_service.dart';
import '../features/auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/update_bar.dart';
import 'app_router.dart';

class MChartApp extends ConsumerStatefulWidget {
  const MChartApp({super.key});

  @override
  ConsumerState<MChartApp> createState() => _MChartAppState();
}

class _MChartAppState extends ConsumerState<MChartApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  void _syncPush(AuthState? before, AuthState now) {
    final push = ref.read(pushServiceProvider);
    if (now is Authenticated && before is! Authenticated) {
      unawaited(push.start());
    } else if (now is! Authenticated && before is Authenticated) {
      unawaited(push.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, _syncPush);
    final router = ref.watch(routerProvider);
    // Until bootstrap has read the stored token, keep the shell out of the
    // tree: its screens fetch on build, and a token-less 401 there would
    // sign the user out.
    final booting = ref.watch(authControllerProvider) is AuthUnknown;
    return MaterialApp.router(
      title: 'MChart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      builder: (context, child) => booting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                const UpdateBar(),
                Expanded(child: child!),
              ],
            ),
    );
  }
}
