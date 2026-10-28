import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
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
      builder: (context, child) => booting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    );
  }
}
