import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/auth_controller.dart';
import '../features/chat/chat_repository.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/notifications/notifications_panel.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../theme/app_color.dart';
import '../theme/app_spacing.dart';
import '../widgets/avatar.dart';
import '../widgets/mchart_logo.dart';
import '../widgets/pills.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _bellKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Warm the realtime connection + notification stream once we're in the shell.
    Future.microtask(() {
      ref.read(realtimeClientProvider).connect();
      ref.read(notificationsControllerProvider);
    });
  }

  void _openNotifications() {
    final box = _bellKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset(box.size.width, box.size.height + 8));
    showNotificationsPanel(context, anchor: offset);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColor.canvas,
      body: Row(
        children: [
          _Sidebar(user: user),
          Expanded(
            child: Column(
              children: [
                _TopBar(bellKey: _bellKey, onBell: _openNotifications),
                const Divider(height: 1),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final unread = ref.watch(
      notificationsControllerProvider.select((s) => s.unread),
    );
    final channelUnread = ref.watch(conversationsProvider).maybeWhen(
          data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
          orElse: () => 0,
        );

    return Container(
      width: AppLayout.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColor.sidebar,
        border: Border(right: BorderSide(color: AppColor.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                const MChartLogo(size: 34),
                Gap.md,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MChart',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                    Text('MbuniTech Work',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.2)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 8),
            child: Text('WORKSPACE',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          _NavItem(
            icon: Icons.forum_outlined,
            label: 'Chats',
            active: location.startsWith('/chats'),
            trailing: channelUnread > 0
                ? CountBadge(channelUnread)
                : const _MiniTag('#prog'),
            onTap: () => context.go('/chats'),
          ),
          _NavItem(
            icon: Icons.checklist_rounded,
            label: 'Tasks',
            active: location.startsWith('/tasks'),
            onTap: () => context.go('/tasks'),
          ),
          _NavItem(
            icon: Icons.space_dashboard_outlined,
            label: 'Dashboard',
            active: location.startsWith('/dashboard'),
            onTap: () => context.go('/dashboard'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Divider(height: 1),
          ),
          _NavItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            active: false,
            trailing: unread > 0
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColor.warning, shape: BoxShape.circle),
                  )
                : null,
            onTap: () {
              final bell = context
                  .findAncestorStateOfType<_AppShellState>();
              bell?._openNotifications();
            },
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: location.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),
          const Spacer(),
          const Divider(height: 1),
          _UserCard(user: user),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? AppColor.brand : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon,
                    size: 19,
                    color: active ? Colors.white : AppColor.textSecondary),
                Gap.md,
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColor.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: AppColor.brandSoft, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColor.brand)),
      );
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -8),
      position: PopupMenuPosition.over,
      onSelected: (v) {
        if (v == 'logout') ref.read(authControllerProvider.notifier).logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(user.email, style: Theme.of(context).textTheme.bodySmall),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AppAvatar.forUser(user, size: 34),
            Gap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    user.role.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColor.warning),
                  ),
                ],
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.bellKey, required this.onBell});
  final Key bellKey;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(realtimeConnectedProvider).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
    final unread =
        ref.watch(notificationsControllerProvider.select((s) => s.unread));
    final user = ref.watch(currentUserProvider)!;

    return Container(
      height: AppLayout.topBarHeight,
      color: AppColor.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Flexible(
            child: Text('MbuniTech Enterprise Network',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Gap.md,
          StatusPill(
            connected ? 'Operational' : 'Reconnecting',
            color: connected ? AppColor.success : AppColor.warning,
            background: connected ? AppColor.successSoft : AppColor.warningSoft,
            dot: true,
          ),
          const Spacer(),
          const SizedBox(
            width: 240,
            child: _SearchField(hint: 'Search workspace...'),
          ),
          Gap.md,
          _IconButton(
            key: bellKey,
            icon: Icons.notifications_none_rounded,
            badge: unread,
            onTap: onBell,
          ),
          Gap.sm,
          AppAvatar.forUser(user, size: 30),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        fillColor: AppColor.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColor.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColor.border),
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({super.key, required this.icon, required this.onTap, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            backgroundColor: AppColor.surfaceMuted,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: CountBadge(badge, color: AppColor.danger),
          ),
      ],
    );
  }
}
