import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../auth/auth_controller.dart';
import 'task_form.dart';
import 'task_repository.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      backgroundColor: AppColor.canvas,
      appBar: AppBar(
        backgroundColor: AppColor.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColor.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/tasks'),
        ),
        title: Text('#TASK-$taskId', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: task.when(
        loading: () => const LoadingBlock(height: 400),
        error: (e, _) => ErrorBlock(
          message: '$e',
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (t) => _Detail(task: t),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 720;
              final main = _MainColumn(task: task);
              final side = _SideColumn(task: task);
              if (!wide) return Column(children: [main, Gap.lg, side]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: main),
                  Gap.lg,
                  Expanded(flex: 2, child: side),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MainColumn extends ConsumerWidget {
  const _MainColumn({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusStepper(status: task.status),
              const Divider(height: 28),
              Row(
                children: [
                  StatusPill(task.priority.label,
                      color: task.priority.color,
                      background: task.priority.color.withValues(alpha: 0.12)),
                  const Spacer(),
                  if (task.isOverdue)
                    StatusPill.danger('Overdue', icon: Icons.warning_amber_rounded),
                ],
              ),
              Gap.md,
              Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
              if (task.description != null && task.description!.isNotEmpty) ...[
                Gap.md,
                Text(task.description!, style: Theme.of(context).textTheme.bodyLarge),
              ],
              Gap.lg,
              _WorkflowBar(task: task),
            ],
          ),
        ),
        Gap.lg,
        if (task.attachments.isNotEmpty) ...[
          SectionCard(
            title: 'Attachments',
            child: Column(
              children: [
                for (final a in task.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      a.isImage
                          ? Icons.image_outlined
                          : a.isVoice
                              ? Icons.mic_none_rounded
                              : Icons.insert_drive_file_outlined,
                      color: AppColor.textSecondary,
                    ),
                    title: Text(a.fileName ?? 'Attachment',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColor.textPrimary)),
                    subtitle: Text(
                      '${Fmt.fileSize(a.fileSize)}'
                      '${a.durationSeconds != null ? ' · ${Fmt.duration(a.durationSeconds)}' : ''}'
                      '${a.uploader != null ? ' · ${a.uploader!.name}' : ''}',
                    ),
                    trailing: const Icon(Icons.download_rounded, size: 18),
                  ),
              ],
            ),
          ),
          Gap.lg,
        ],
        _Comments(task: task),
      ],
    );
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});
  final TaskStatus status;

  static const _flow = [
    TaskStatus.assigned,
    TaskStatus.inProgress,
    TaskStatus.completed,
    TaskStatus.approved,
  ];

  @override
  Widget build(BuildContext context) {
    // "Needs Revision" sits off the happy path — show it inline when active.
    final isRevision = status == TaskStatus.revision;
    final currentIndex = isRevision ? 1 : _flow.indexOf(status);

    return Row(
      children: [
        for (var i = 0; i < _flow.length; i++) ...[
          _Step(
            label: _flow[i].label,
            done: i < currentIndex,
            active: i == currentIndex && !isRevision,
            warn: i == currentIndex && isRevision,
          ),
          if (i != _flow.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < currentIndex ? AppColor.brand : AppColor.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.active,
    required this.warn,
  });

  final String label;
  final bool done;
  final bool active;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? AppColor.danger
        : (done || active)
            ? AppColor.brand
            : AppColor.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? AppColor.brand : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : warn
                  ? const Icon(Icons.priority_high_rounded, size: 12, color: AppColor.danger)
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          warn ? 'Needs Revision' : label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active || warn ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WorkflowBar extends ConsumerStatefulWidget {
  const _WorkflowBar({required this.task});
  final Task task;

  @override
  ConsumerState<_WorkflowBar> createState() => _WorkflowBarState();
}

class _WorkflowBarState extends ConsumerState<_WorkflowBar> {
  bool _busy = false;

  Future<void> _run(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      await ref.read(taskRepositoryProvider).transition(widget.task.id, action, note: note);
      ref.invalidate(taskDetailProvider(widget.task.id));
      ref.invalidate(taskBoardProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnForRevision() async {
    final note = await _askNote(context);
    if (note != null && note.trim().isNotEmpty) _run('return', note: note.trim());
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final me = ref.watch(currentUserProvider);
    if (me == null) return const SizedBox.shrink();

    final isAssignee = task.assignee?.id == me.id;
    final canReview = me.role == UserRole.admin ||
        task.creator?.id == me.id ||
        (me.role == UserRole.manager && task.departmentId == me.departmentId);
    final allowed = task.allowedTransitions.toSet();

    final buttons = <Widget>[
      if (isAssignee && allowed.contains('in_progress'))
        FilledButton.icon(
          onPressed: _busy ? null : () => _run('start'),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Start Task'),
        ),
      if (isAssignee && allowed.contains('completed'))
        FilledButton.icon(
          onPressed: _busy ? null : () => _run('complete'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Mark Completed'),
        ),
      if (canReview && allowed.contains('approved'))
        FilledButton.icon(
          onPressed: _busy ? null : () => _run('approve'),
          style: FilledButton.styleFrom(backgroundColor: AppColor.success),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text('Approve'),
        ),
      if (canReview && allowed.contains('revision'))
        OutlinedButton.icon(
          onPressed: _busy ? null : _returnForRevision,
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Return for Revision'),
        ),
    ];

    if (buttons.isEmpty) {
      return Text(
        task.status == TaskStatus.approved
            ? 'This task has been approved and completed.'
            : 'No action is needed from you right now.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<String?> _askNote(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reason for returning'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Explain what needs to be fixed...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }
}

class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.task});
  final Task task;

  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskRepositoryProvider).comment(widget.task.id, text);
      _controller.clear();
      ref.invalidate(taskDetailProvider(widget.task.id));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.task.comments;
    return SectionCard(
      title: 'Task Discussion',
      subtitle: '${comments.length} comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No comments yet',
              ),
            )
          else
            for (final c in comments) ...[
              _CommentTile(comment: c),
              Gap.md,
            ],
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Write a comment...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              Gap.sm,
              FilledButton(
                onPressed: _busy ? null : _send,
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.user != null)
          AppAvatar.forUser(comment.user!, size: 28)
        else
          const AppAvatar(label: '?', size: 28),
        Gap.md,
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: comment.isRevisionNote ? AppColor.warningSoft : AppColor.surfaceMuted,
              borderRadius: AppRadius.md,
              border: comment.isRevisionNote
                  ? Border.all(color: AppColor.warning.withValues(alpha: 0.4))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.user?.name ?? 'User',
                        style: Theme.of(context).textTheme.titleSmall),
                    if (comment.isRevisionNote) ...[
                      Gap.sm,
                      StatusPill.warning('Revision'),
                    ],
                    const Spacer(),
                    Text(Fmt.relative(comment.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
                Gap.xs,
                Text(comment.comment, style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColor.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideColumn extends ConsumerWidget {
  const _SideColumn({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final canEdit = me != null &&
        (me.role == UserRole.admin || task.creator?.id == me.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Details', style: Theme.of(context).textTheme.titleMedium)),
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => showTaskForm(context, ref, task: task),
                    ),
                ],
              ),
              Gap.sm,
              _MetaRow(label: 'Assignee', child: _person(context, task.assignee)),
              _MetaRow(label: 'Created by', child: _person(context, task.creator)),
              _MetaRow(
                label: 'Deadline',
                child: Text(Fmt.deadline(task.deadline),
                    style: TextStyle(
                        color: task.isOverdue ? AppColor.danger : AppColor.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              _MetaRow(
                label: 'Created',
                child: Text(Fmt.relative(task.createdAt)),
              ),
            ],
          ),
        ),
        Gap.lg,
        SectionCard(
          title: 'Status History',
          child: task.statusHistory.isEmpty
              ? const Text('No changes yet.')
              : Column(
                  children: [
                    for (final e in task.statusHistory) _HistoryTile(event: e),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _person(BuildContext context, User? user) {
    if (user == null) return const Text('—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar.forUser(user, size: 22),
        Gap.sm,
        Flexible(child: Text(user.name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColor.textPrimary),
              child: child,
            )),
          ],
        ),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});
  final TaskStatusEvent event;

  @override
  Widget build(BuildContext context) {
    final to = TaskStatus.from(event.newStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: to.color, shape: BoxShape.circle),
            ),
          ),
          Gap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.oldStatus == null ? 'Created' : TaskStatus.from(event.oldStatus).label} → ${to.label}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${event.changedBy?.name ?? 'System'} · ${Fmt.relative(event.changedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Text('“${event.note}”',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
