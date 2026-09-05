import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../models/enums.dart';
import 'app_shell.dart';

/// Bridges the Riverpod auth state to a Listenable go_router can refresh on.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/tasks',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';

      if (auth is AuthUnknown || auth is AuthLoading) return null;

      if (auth is! Authenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/tasks';

      // Route by role: Dashboard is manager/admin, Settings is admin-only —
      // one login for everyone, but where it lands (and what a typed URL
      // resolves to) depends on the account's role.
      final role = auth.user.role;
      final path = state.matchedLocation;
      if (path.startsWith('/dashboard') && !role.isManagerOrAdmin)
        return '/tasks';
      if (path.startsWith('/settings') && role != UserRole.admin)
        return '/tasks';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/tasks',
            pageBuilder: (c, s) => const NoTransitionPage(child: TasksScreen()),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootKey,
                builder: (c, s) => TaskDetailScreen(
                  taskId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/chats',
            pageBuilder: (c, s) => NoTransitionPage(
              child: ChatScreen(
                conversationId: int.tryParse(s.uri.queryParameters['c'] ?? ''),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
