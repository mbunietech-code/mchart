import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/announcement.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../auth/auth_controller.dart';
import 'announcement_form.dart';
import 'announcement_repository.dart';

/// Status / Announcements: official notices, separate from chat.
class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final q = ref.read(announcementQueryProvider);
      ref.read(announcementQueryProvider.notifier).state = q.copyWith(
        search: v.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(announcementsProvider);
    final query = ref.watch(announcementQueryProvider);
    final me = ref.watch(currentUserProvider);
    final canPost = me?.isManagerOrAdmin ?? false;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final hPad = narrow ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canPost && narrow
          ? FloatingActionButton.extended(
              onPressed: () => showAnnouncementForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Announce'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, narrow ? 14 : 22, hPad, 8),
            child: PageHeader(
              breadcrumb: 'Mbunietech • Status',
              title: 'Announcements',
              subtitle: narrow
                  ? null
                  : 'Official notices, meetings and reminders for the team.',
              actions: [
                SizedBox(
                  width: narrow ? double.infinity : 240,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search announcements...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                    onChanged: _search,
                  ),
                ),
                if (canPost && !narrow)
                  FilledButton.icon(
                    onPressed: () => showAnnouncementForm(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New announcement'),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: query.category == null,
                  onTap: () => _setQuery(query.copyWith(category: null)),
                ),
                for (final c in AnnouncementCategory.values)
                  _FilterChip(
                    label: c.label,
                    icon: c.icon,
                    color: c.color,
                    selected: query.category == c,
                    onTap: () => _setQuery(
                      query.copyWith(category: query.category == c ? null : c),
                    ),
                  ),
                _FilterChip(
                  label: 'Archived',
                  icon: Icons.inventory_2_outlined,
                  selected: query.archived,
                  onTap: () =>
                      _setQuery(query.copyWith(archived: !query.archived)),
                ),
              ],
            ),
          ),
          Gap.sm,
          Expanded(
            child: list.when(
              loading: () => const LoadingBlock(height: 300),
              error: (e, _) => ErrorBlock(
                message: '$e',
                onRetry: () => ref.invalidate(announcementsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: query.archived
                        ? 'No archived announcements'
                        : 'No announcements yet',
                    message: canPost && !query.archived
                        ? 'Post a notice and the team is notified right away.'
                        : 'Official notices from your managers will appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(announcementsProvider);
                    ref.invalidate(announcementUnreadProvider);
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Gap.md,
                    itemBuilder: (context, i) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _AnnouncementCard(
                          announcement: items[i],
                          onOpen: () =>
                              openAnnouncement(context, ref, items[i]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setQuery(AnnouncementQuery q) =>
      ref.read(announcementQueryProvider.notifier).state = q;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColor.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: selected ? Colors.white : c),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColor.textPrimary,
        ),
        selectedColor: c,
        backgroundColor: AppColor.surface,
        side: BorderSide(color: selected ? c : AppColor.border),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.category, {this.size = 40});
  final AnnouncementCategory category;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: category.color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(category.icon, color: category.color, size: size * 0.5),
  );
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onOpen});
  final Announcement announcement;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final t = Theme.of(context).textTheme;
    final urgent = a.category == AnnouncementCategory.urgent;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status-style ring: coloured while unread, grey once seen.
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: a.isRead ? AppColor.border : a.category.color,
                width: 2,
              ),
            ),
            child: _CategoryBadge(a.category),
          ),
          Gap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      a.category.label.toUpperCase(),
                      color: a.category.color,
                      dense: true,
                    ),
                    if (a.pinned) ...[
                      Gap.sm,
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppColor.textSecondary,
                      ),
                    ],
                    const Spacer(),
                    Text(Fmt.relative(a.createdAt), style: t.bodySmall),
                    if (!a.isRead) ...[
                      Gap.sm,
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: a.category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                Gap.sm,
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: a.isRead ? FontWeight.w600 : FontWeight.w700,
                    color: urgent ? AppColor.danger : null,
                  ),
                ),
                Gap.xs,
                Text(
                  a.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: AppColor.textSecondary),
                ),
                if (a.imageUrl != null) ...[
                  Gap.sm,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      announcementImageUrl(a.imageUrl!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheHeight: 420,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                Gap.sm,
                Text(
                  [
                    a.author?.name ?? 'Unknown',
                    a.audienceLabel,
                    if (a.readCount != null) 'Seen by ${a.readCount}',
                  ].join(' • '),
                  style: t.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the full announcement and marks it read.
Future<void> openAnnouncement(
  BuildContext context,
  WidgetRef ref,
  Announcement a,
) async {
  if (!a.isRead) {
    unawaited(
      ref.read(announcementRepositoryProvider).markRead(a.id).then((_) {
        ref.invalidate(announcementsProvider);
        ref.invalidate(announcementUnreadProvider);
      }, onError: (_) {}),
    );
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _AnnouncementViewer(announcement: a.copyWith(isRead: true)),
    ),
  );
}

class _AnnouncementViewer extends ConsumerWidget {
  const _AnnouncementViewer({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: a.category.color,
        foregroundColor: Colors.white,
        title: Text(a.category.label),
        actions: [
          if (a.canManage) _ManageMenu(announcement: a, inViewer: true),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    _CategoryBadge(a.category, size: 44),
                    Gap.md,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.author?.name ?? 'Unknown',
                            style: t.titleSmall,
                          ),
                          Text(
                            '${Fmt.dayHeading(a.createdAt)} • ${Fmt.time(a.createdAt)}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (a.author != null)
                      AppAvatar.forUser(a.author!, size: 36),
                  ],
                ),
                Gap.lg,
                SelectableText(
                  a.title,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.md,
                SelectableText(
                  a.body,
                  style: t.bodyLarge?.copyWith(height: 1.5),
                ),
                if (a.imageUrl != null) ...[
                  Gap.lg,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InteractiveViewer(
                      child: Image.network(
                        announcementImageUrl(a.imageUrl!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Image could not be loaded.'),
                        ),
                      ),
                    ),
                  ),
                ],
                Gap.xl,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      a.audienceLabel,
                      color: AppColor.textSecondary,
                      icon: Icons.people_alt_outlined,
                    ),
                    if (a.pinned)
                      const StatusPill(
                        'Pinned',
                        color: AppColor.textSecondary,
                        icon: Icons.push_pin_rounded,
                      ),
                    if (a.expiresAt != null)
                      StatusPill(
                        'Until ${Fmt.shortDate(a.expiresAt!)} ${Fmt.time(a.expiresAt!)}',
                        color: AppColor.textSecondary,
                        icon: Icons.schedule_rounded,
                      ),
                    if (a.readCount != null)
                      StatusPill(
                        'Seen by ${a.readCount}',
                        color: AppColor.success,
                        icon: Icons.done_all_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageMenu extends ConsumerWidget {
  const _ManageMenu({required this.announcement, this.inViewer = false});
  final Announcement announcement;
  final bool inViewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    return PopupMenuButton<String>(
      tooltip: 'Manage',
      onSelected: (v) async {
        final repo = ref.read(announcementRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);
        try {
          switch (v) {
            case 'edit':
              if (inViewer) nav.pop();
              await showAnnouncementForm(context, ref, existing: a);
              return;
            case 'pin':
              await repo.setFlags(a.id, pinned: !a.pinned);
            case 'archive':
              await repo.setFlags(a.id, archived: !a.archived);
            case 'delete':
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete announcement?'),
                  content: Text('"${a.title}" will be removed for everyone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColor.danger,
                      ),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await repo.delete(a.id);
          }
          ref.invalidate(announcementsProvider);
          ref.invalidate(announcementUnreadProvider);
          if (inViewer) nav.pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(switch (v) {
                'pin' => a.pinned ? 'Unpinned' : 'Pinned to the top',
                'archive' => a.archived ? 'Restored' : 'Archived',
                _ => 'Announcement deleted',
              }),
            ),
          );
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('$e')));
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'pin', child: Text(a.pinned ? 'Unpin' : 'Pin')),
        PopupMenuItem(
          value: 'archive',
          child: Text(a.archived ? 'Restore' : 'Archive'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppColor.danger)),
        ),
      ],
    );
  }
}
