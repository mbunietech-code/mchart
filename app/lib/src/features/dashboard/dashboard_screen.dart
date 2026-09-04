import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/dashboard.dart';
import '../../models/enums.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../directory/directory_repository.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);

    return ListView(
      padding: AppLayout.contentPadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  breadcrumb: 'MbuniTech • Usimamizi wa Shughuli',
                  title: 'Dashibodi ya Meneja — Utendaji & Maendeleo ya Kazi',
                  subtitle:
                      'Muhtasari wa hali ya kazi, tija ya wafanyakazi, na shughuli zilizopangwa ndani ya mtandao wa MChart.',
                  actions: [
                    const _DepartmentFilter(),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Pakua Ripoti'),
                    ),
                  ],
                ),
                Gap.xl,
                summary.when(
                  loading: () => const LoadingBlock(height: 320),
                  error: (e, _) => ErrorBlock(
                    message: '$e',
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                  ),
                  data: (s) => _Body(summary: s),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DepartmentFilter extends ConsumerWidget {
  const _DepartmentFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);
    final selected = ref.watch(dashboardDepartmentProvider);

    return departments.maybeWhen(
      data: (list) => Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColor.borderStrong),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: selected,
            isDense: true,
            borderRadius: AppRadius.md,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColor.textPrimary),
            items: [
              const DropdownMenuItem(value: null, child: Text('Idara Zote (All Depts)')),
              for (final d in list)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => ref.read(dashboardDepartmentProvider.notifier).state = v,
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = summary.counts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(children: [
          StatCard(
            label: 'Kazi Zilizo Wazi',
            value: '${c.open}',
            caption: 'zinazohitaji umakini',
            footLabel: 'Mtiririko wa kazi',
            footValue: StatusPill.success('Salama'),
          ),
          StatCard(
            label: 'Zinazoendelea',
            value: '${c.inProgress}',
            badge: StatusPill.brand('In Action', icon: Icons.bolt_rounded),
            caption: 'kwa sasa mikononi',
            footLabel: 'Zilizorudishwa marekebisho',
            footValue: Text('${c.revision}',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          StatCard(
            label: 'Zilizokamilika',
            value: '${c.completed + c.approved}',
            badge: summary.completionRate != null
                ? TrendChip(delta: summary.completionRate!.round())
                : null,
            caption: 'zimethibitishwa ${c.approved}',
            footLabel: 'Zilizoidhinishwa kipindi hiki',
            footValue: Text('${summary.approvedInPeriod}',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          StatCard(
            label: 'Zilizochelewa',
            value: '${c.overdue}',
            badge: c.overdue > 0
                ? StatusPill.danger('Tahadhari', icon: Icons.warning_amber_rounded)
                : StatusPill.success('Hakuna'),
            caption: 'zinahitaji hatua za haraka',
            footLabel: 'Jumla ya kazi',
            footValue: Text('${c.total}',
                style: Theme.of(context).textTheme.titleSmall),
          ),
        ]),
        Gap.lg,
        LayoutBuilder(builder: (context, cns) {
          final twoCol = cns.maxWidth > 900;
          final left = _CompletionByAssignee(summary: summary);
          final right = const _ActivityFeed();
          if (!twoCol) {
            return Column(children: [left, Gap.lg, SizedBox(height: 420, child: right)]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: left),
                Gap.lg,
                Expanded(flex: 2, child: right),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 1);
      final width = (c.maxWidth - (perRow - 1) * 14) / perRow;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    });
  }
}

class _CompletionByAssignee extends StatelessWidget {
  const _CompletionByAssignee({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = summary.perAssignee.take(6).toList();
    final rate = summary.completionRate;

    return SectionCard(
      title: 'Kiwango cha Ukamilishaji Kazi kwa Mfanyakazi',
      subtitle: 'Kulinganisha kazi zilizoidhinishwa na jumla ya kazi walizopewa.',
      footer: Row(
        children: [
          const Expanded(
            child: Text(
              'Ufuatiliaji unafanyika kiotomatiki kupitia mfumo wa MChart.',
              style: TextStyle(fontSize: 11, color: AppColor.textMuted),
            ),
          ),
          Text('Tazama Uchambuzi wa Kina',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColor.brand)),
          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColor.brand),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColor.brandSoft,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.track_changes_rounded, size: 18, color: AppColor.brand),
                Gap.sm,
                Expanded(
                  child: Text(
                    'Lengo la Utendaji la MbuniTech: 85% ya kazi kuidhinishwa kila mzunguko.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColor.brand, fontWeight: FontWeight.w500),
                  ),
                ),
                if (rate != null)
                  StatusPill(
                    '${rate >= 85 ? '+' : ''}${(rate - 85).toStringAsFixed(1)}%',
                    color: rate >= 85 ? AppColor.success : AppColor.warning,
                    background: rate >= 85 ? AppColor.successSoft : AppColor.warningSoft,
                    dense: true,
                  ),
              ],
            ),
          ),
          Gap.lg,
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: 'Hakuna data ya kutosha bado',
                message: 'Kazi zitakapoanza kupewa, takwimu zitaonekana hapa.',
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _AssigneeRow(
                stat: rows[i],
                color: AppColor.departmentPalette[i % AppColor.departmentPalette.length],
              ),
              if (i != rows.length - 1) Gap.lg,
            ],
        ],
      ),
    );
  }
}

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({required this.stat, required this.color});
  final AssigneeStat stat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (stat.progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppAvatar(label: _initials(stat.assignee), size: 24, color: color),
            Gap.sm,
            Expanded(
              child: Text(stat.assignee ?? 'Haijapangwa',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            Text('${stat.approved}/${stat.total} kazi',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
            Gap.md,
            SizedBox(
              width: 42,
              child: Text('$pct%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
        Gap.sm,
        AppProgressBar(value: stat.progress, color: color),
        if (stat.overdue > 0) ...[
          Gap.xs,
          Text('${stat.overdue} zimechelewa',
              style: const TextStyle(fontSize: 11, color: AppColor.danger)),
        ],
      ],
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '—';
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _ActivityFeed extends ConsumerWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dashboardActivityProvider);

    return SectionCard(
      title: 'Mwenendo wa Hivi Karibuni',
      subtitle: 'Matukio ya sasa kwenye miradi na mawasiliano.',
      trailing: const LivePill(online: true, onlineLabel: 'Moja kwa Moja'),
      footer: Center(
        child: Text('Tazama Historia Yote ya Matukio',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.brand)),
      ),
      child: activity.when(
        loading: () => const LoadingBlock(height: 220),
        error: (e, _) => ErrorBlock(message: '$e'),
        data: (events) => events.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'Hakuna matukio bado',
              )
            : Column(
                children: [
                  for (final e in events.take(6)) _ActivityRow(event: e),
                ],
              ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});
  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final status = TaskStatus.from(event.newStatus);
    return InkWell(
      borderRadius: AppRadius.sm,
      onTap: event.taskId == null ? null : () => context.push('/tasks/${event.taskId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: status.softColor, borderRadius: AppRadius.sm),
              child: Icon(_iconFor(status), size: 15, color: status.color),
            ),
            Gap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.actor ?? 'Mfumo',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Text(Fmt.relative(event.at),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                  Gap.xs,
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${status.label} '),
                      TextSpan(
                        text: event.taskTitle == null
                            ? '#TASK-${event.taskId ?? ''}'
                            : '#TASK-${event.taskId} — ${event.taskTitle}',
                        style: const TextStyle(color: AppColor.brand, fontWeight: FontWeight.w600),
                      ),
                    ]),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.note != null && event.note!.isNotEmpty) ...[
                    Gap.xs,
                    Text('“${event.note}”',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(TaskStatus s) => switch (s) {
        TaskStatus.approved => Icons.verified_rounded,
        TaskStatus.completed => Icons.check_circle_outline_rounded,
        TaskStatus.inProgress => Icons.play_circle_outline_rounded,
        TaskStatus.revision => Icons.replay_rounded,
        TaskStatus.assigned => Icons.assignment_outlined,
      };
}
