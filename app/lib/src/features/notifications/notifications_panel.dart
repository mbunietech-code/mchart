import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/app_notification.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/primitives.dart';
import 'notifications_controller.dart';

Future<void> showNotificationsPanel(BuildContext context, {required Offset anchor}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => Stack(
      children: [
        Positioned(
          right: 20,
          top: anchor.dy,
          child: const _Panel(),
        ),
      ],
    ),
  );
}

class _Panel extends ConsumerWidget {
  const _Panel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    final today = <AppNotification>[];
    final earlier = <AppNotification>[];
    final now = DateTime.now();
    for (final n in state.items) {
      (now.difference(n.createdAt).inHours < 24 && now.day == n.createdAt.day
              ? today
              : earlier)
          .add(n);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColor.border),
          boxShadow: AppShadow.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
                  Gap.sm,
                  if (state.unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColor.danger, borderRadius: BorderRadius.circular(999)),
                      child: Text('${state.unread} New',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: state.unread == 0 ? null : controller.markAllRead,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Mark all as read'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: state.loading
                  ? const LoadingBlock(height: 200)
                  : state.items.isEmpty
                      ? const SizedBox(
                          height: 220,
                          child: EmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'No notifications',
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            if (today.isNotEmpty) ...[
                              const _GroupLabel('Today'),
                              for (final n in today)
                                _NotificationRow(notification: n, controller: controller),
                            ],
                            if (earlier.isNotEmpty) ...[
                              const _GroupLabel('Earlier'),
                              for (final n in earlier)
                                _NotificationRow(notification: n, controller: controller),
                            ],
                          ],
                        ),
            ),
            const Divider(height: 1),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Close',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.brand)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.controller});
  final AppNotification notification;
  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual(notification.type);
    return InkWell(
      onTap: () {
        controller.markRead(notification.id);
        if (notification.taskId != null) {
          Navigator.pop(context);
          context.push('/tasks/${notification.taskId}');
        } else if (notification.conversationId != null) {
          Navigator.pop(context);
          context.go('/chats?c=${notification.conversationId}');
        }
      },
      child: Container(
        color: notification.isRead ? null : AppColor.brandSoft.withValues(alpha: 0.4),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), borderRadius: AppRadius.sm),
              child: Icon(icon, size: 16, color: color),
            ),
            Gap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (notification.body != null && notification.body!.isNotEmpty) ...[
                    Gap.xs,
                    Text(notification.body!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  Gap.xs,
                  Text(Fmt.relative(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10.5, color: AppColor.textMuted)),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColor.brand, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _visual(String type) => switch (type) {
        'task_assigned' => (Icons.assignment_ind_outlined, AppColor.brand),
        'task_completed' => (Icons.check_circle_outline_rounded, AppColor.accent),
        'task_approved' => (Icons.verified_outlined, AppColor.success),
        'task_revision' => (Icons.replay_rounded, AppColor.danger),
        'task_started' => (Icons.play_circle_outline_rounded, AppColor.brand),
        'task_comment' => (Icons.mode_comment_outlined, AppColor.slate),
        'new_message' => (Icons.chat_bubble_outline_rounded, AppColor.brand),
        _ => (Icons.notifications_none_rounded, AppColor.slate),
      };
}
