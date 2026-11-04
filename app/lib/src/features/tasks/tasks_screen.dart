import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../../widgets/page_header.dart';
import '../auth/auth_controller.dart';
import 'task_form.dart';
import 'task_repository.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  static const _columns = [
    TaskStatus.assigned,
    TaskStatus.inProgress,
    TaskStatus.completed,
    TaskStatus.revision,
    TaskStatus.approved,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(taskBoardProvider);
    final filter = ref.watch(taskFilterProvider);
    final me = ref.watch(currentUserProvider);
    final canCreate = me?.role.isManagerOrAdmin ?? false;

    return Column(
      children: [
        Padding(
          padding: MediaQuery.sizeOf(context).width < 600
              ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
              : const EdgeInsets.fromLTRB(28, 22, 28, 12),
          child: PageHeader(
            breadcrumb: 'Mbunietech • Task Management',
            title: 'Task Board',
            subtitle:
                'Track every task from assignment to approval — with priority, deadlines and attachments.',
            actions: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 600 ? 170 : 240,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                  onChanged: (v) =>
                      ref.read(taskFilterProvider.notifier).state = filter
                          .copyWith(search: v),
                ),
              ),
              _ToggleChip(
                label: 'Overdue',
                active: filter.overdue,
                onTap: () => ref.read(taskFilterProvider.notifier).state =
                    filter.copyWith(overdue: !filter.overdue),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => showTaskForm(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Task'),
                ),
            ],
          ),
        ),
        Expanded(
          child: board.when(
            loading: () => const LoadingBlock(height: 400),
            error: (e, _) => ErrorBlock(
              message: '$e',
              onRetry: () => ref.invalidate(taskBoardProvider),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'No tasks yet',
                  message: 'New tasks will appear here once they\'re created.',
                );
              }
              // One tab per status (no sideways board); each tab's cards
              // scroll on their own.
              final side = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 28.0;
              return DefaultTabController(
                length: _columns.length,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: side - 12),
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final status in _columns)
                            Tab(
                              child: _TabLabel(
                                status: status,
                                count: tasks
                                    .where((t) => t.status == status)
                                    .length,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final status in _columns)
                            RefreshIndicator(
                              onRefresh: () async =>
                                  ref.invalidate(taskBoardProvider),
                              child: _StatusList(
                                status: status,
                                side: side,
                                tasks: tasks
                                    .where((t) => t.status == status)
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColor.brandSoft : AppColor.surface,
        side: BorderSide(
          color: active ? AppColor.brand : AppColor.borderStrong,
        ),
        foregroundColor: active ? AppColor.brand : AppColor.textPrimary,
      ),
      child: Text(label),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.status, required this.count});
  final TaskStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        Gap.sm,
        Text(status.label),
        Gap.sm,
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColor.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StatusList extends StatelessWidget {
  const _StatusList({
    required this.status,
    required this.tasks,
    required this.side,
  });
  final TaskStatus status;
  final List<Task> tasks;
  final double side;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(side, 16, side, 24);
    if (tasks.isEmpty) {
      return ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.checklist_rounded,
            title: 'No ${status.label.toLowerCase()} tasks',
            message: 'Tasks in this stage will show here.',
          ),
        ],
      );
    }
    // Phones get one column; wider windows lay cards out side by side.
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - side * 2;
        final perRow = (inner / 380).floor().clamp(1, 4);
        final cardWidth = (inner - 16 * (perRow - 1)) / perRow;
        return SingleChildScrollView(
          padding: padding,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final t in tasks)
                SizedBox(
                  width: cardWidth,
                  child: _TaskCard(task: t),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/tasks/${task.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                task.priority.label,
                color: task.priority.color,
                background: task.priority.color.withValues(alpha: 0.12),
                dense: true,
              ),
              const Spacer(),
              Text(
                '#TASK-${task.id}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          Gap.sm,
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(height: 1.3),
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            Gap.xs,
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ],
          Gap.md,
          Row(
            children: [
              if (task.assignee != null)
                AppAvatar.forUser(task.assignee!, size: 22),
              Gap.sm,
              Expanded(
                child: Text(
                  task.assignee?.name ?? 'Unassigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ),
              if (task.deadline != null)
                StatusPill(
                  Fmt.deadline(task.deadline),
                  color: task.isOverdue
                      ? AppColor.danger
                      : AppColor.textSecondary,
                  background: task.isOverdue
                      ? AppColor.dangerSoft
                      : AppColor.surfaceMuted,
                  icon: Icons.schedule_rounded,
                  dense: true,
                ),
            ],
          ),
          if ((task.commentsCount ?? 0) > 0 ||
              (task.attachmentsCount ?? 0) > 0) ...[
            Gap.sm,
            Row(
              children: [
                if ((task.commentsCount ?? 0) > 0) ...[
                  const Icon(
                    Icons.mode_comment_outlined,
                    size: 13,
                    color: AppColor.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${task.commentsCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColor.textMuted,
                    ),
                  ),
                  Gap.md,
                ],
                if ((task.attachmentsCount ?? 0) > 0) ...[
                  const Icon(
                    Icons.attach_file_rounded,
                    size: 13,
                    color: AppColor.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${task.attachmentsCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColor.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
