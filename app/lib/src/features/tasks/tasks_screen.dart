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
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
          child: PageHeader(
            breadcrumb: 'MbuniTech • Task Management',
            title: 'Task Board',
            subtitle:
                'Track every task from assignment to approval — with priority, deadlines and attachments.',
            actions: [
              SizedBox(
                width: 240,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                  onChanged: (v) => ref.read(taskFilterProvider.notifier).state =
                      filter.copyWith(search: v),
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
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(taskBoardProvider),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final status in _columns) ...[
                        _Column(
                          status: status,
                          tasks: tasks.where((t) => t.status == status).toList(),
                        ),
                        Gap.lg,
                      ],
                    ],
                  ),
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
  const _ToggleChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColor.brandSoft : AppColor.surface,
        side: BorderSide(color: active ? AppColor.brand : AppColor.borderStrong),
        foregroundColor: active ? AppColor.brand : AppColor.textPrimary,
      ),
      child: Text(label),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.status, required this.tasks});
  final TaskStatus status;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
              ),
              Gap.sm,
              Text(status.label, style: Theme.of(context).textTheme.titleSmall),
              Gap.sm,
              Text('${tasks.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColor.textMuted)),
            ],
          ),
          Gap.md,
          if (tasks.isEmpty)
            Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColor.border, style: BorderStyle.solid),
                color: AppColor.surfaceMuted,
              ),
              child: Text('None',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColor.textMuted)),
            )
          else
            for (final task in tasks) ...[
              _TaskCard(task: task),
              Gap.md,
            ],
        ],
      ),
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
              Text('#TASK-${task.id}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
          Gap.sm,
          Text(task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.3)),
          if (task.description != null && task.description!.isNotEmpty) ...[
            Gap.xs,
            Text(task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
          ],
          Gap.md,
          Row(
            children: [
              if (task.assignee != null)
                AppAvatar.forUser(task.assignee!, size: 22),
              Gap.sm,
              Expanded(
                child: Text(task.assignee?.name ?? 'Unassigned',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
              ),
              if (task.deadline != null)
                StatusPill(
                  Fmt.deadline(task.deadline),
                  color: task.isOverdue ? AppColor.danger : AppColor.textSecondary,
                  background: task.isOverdue ? AppColor.dangerSoft : AppColor.surfaceMuted,
                  icon: Icons.schedule_rounded,
                  dense: true,
                ),
            ],
          ),
          if ((task.commentsCount ?? 0) > 0 || (task.attachmentsCount ?? 0) > 0) ...[
            Gap.sm,
            Row(
              children: [
                if ((task.commentsCount ?? 0) > 0) ...[
                  const Icon(Icons.mode_comment_outlined, size: 13, color: AppColor.textMuted),
                  const SizedBox(width: 3),
                  Text('${task.commentsCount}',
                      style: const TextStyle(fontSize: 11, color: AppColor.textMuted)),
                  Gap.md,
                ],
                if ((task.attachmentsCount ?? 0) > 0) ...[
                  const Icon(Icons.attach_file_rounded, size: 13, color: AppColor.textMuted),
                  const SizedBox(width: 3),
                  Text('${task.attachmentsCount}',
                      style: const TextStyle(fontSize: 11, color: AppColor.textMuted)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
