import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_card.dart';
import '../auth/auth_controller.dart';
import '../directory/directory_repository.dart';
import 'user_form.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final isAdmin = me?.role == UserRole.admin;
    final departments = ref.watch(departmentsProvider);

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
                  breadcrumb: 'Mfumo wa Uendeshaji • Usimamizi wa Shirika',
                  title: 'Mipangilio ya Msimamizi',
                  subtitle:
                      'Simamia watumiaji, idara, na majukumu ndani ya mtandao wa MbuniTech.',
                  actions: [
                    if (isAdmin && _tab == 0)
                      FilledButton.icon(
                        onPressed: () => showUserForm(context, ref),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Alika Mtumiaji'),
                      ),
                  ],
                ),
                Gap.xl,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ref.watch(usersProvider).maybeWhen(
                          data: (p) => StatChip(
                            icon: Icons.groups_outlined,
                            value: '${p.total}',
                            label: 'Wafanyakazi',
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                    departments.maybeWhen(
                      data: (d) => StatChip(
                        icon: Icons.apartment_rounded,
                        value: '${d.length}',
                        label: 'Idara Zilizosajiliwa',
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                Gap.xl,
                _Tabs(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Gap.lg,
                if (!isAdmin)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Sehemu ya Msimamizi',
                      message: 'Ni Admin pekee anayeweza kufikia mipangilio hii.',
                    ),
                  )
                else
                  switch (_tab) {
                    0 => const _UsersTab(),
                    1 => const _DepartmentsTab(),
                    _ => const _RolesTab(),
                  },
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['Watumiaji (Users)', 'Idara (Departments)', 'Majukumu (Roles)'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == i ? AppColor.brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: index == i ? AppColor.brand : AppColor.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Users tab
// ---------------------------------------------------------------------------

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final query = ref.watch(userQueryProvider);
    final departments = ref.watch(departmentsProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tafuta kwa jina, barua pepe, au idara...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                    onChanged: (v) => ref.read(userQueryProvider.notifier).state =
                        query.copyWith(search: v, page: 1),
                  ),
                ),
                Gap.md,
                departments.maybeWhen(
                  data: (list) => _FilterDropdown<int?>(
                    value: query.departmentId,
                    hint: 'Idara Zote',
                    items: {
                      null: 'Idara Zote',
                      for (final d in list) d.id: d.name,
                    },
                    onChanged: (v) => ref.read(userQueryProvider.notifier).state =
                        query.copyWith(departmentId: v, page: 1),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                Gap.sm,
                _FilterDropdown<String?>(
                  value: query.role,
                  hint: 'Majukumu Yote',
                  items: const {
                    null: 'Majukumu Yote',
                    'admin': 'Admin',
                    'manager': 'Manager',
                    'staff': 'Staff',
                  },
                  onChanged: (v) => ref.read(userQueryProvider.notifier).state =
                      query.copyWith(role: v, page: 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          users.when(
            loading: () => const LoadingBlock(height: 260),
            error: (e, _) => ErrorBlock(
              message: '$e',
              onRetry: () => ref.invalidate(usersProvider),
            ),
            data: (page) => Column(
              children: [
                const _UserHeaderRow(),
                const Divider(height: 1),
                if (page.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Hakuna mtumiaji',
                    ),
                  )
                else
                  for (final u in page.items) _UserRow(user: u),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(
                        'Inaonyesha ${page.items.length} kati ya ${page.total}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: page.currentPage > 1
                            ? () => ref.read(userQueryProvider.notifier).state =
                                query.copyWith(page: page.currentPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text('${page.currentPage} / ${page.lastPage}',
                          style: Theme.of(context).textTheme.bodySmall),
                      IconButton(
                        onPressed: page.hasMore
                            ? () => ref.read(userQueryProvider.notifier).state =
                                query.copyWith(page: page.currentPage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String hint;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColor.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColor.textPrimary),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}

class _UserHeaderRow extends StatelessWidget {
  const _UserHeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget cell(String s, int flex) => Expanded(
          flex: flex,
          child: Text(s.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        );
    return Container(
      color: AppColor.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          cell('Mfanyakazi', 4),
          cell('Idara', 2),
          cell('Jukumu', 2),
          cell('Hali', 2),
          cell('Mara ya mwisho', 2),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                AppAvatar.forUser(user, size: 34),
                Gap.md,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColor.brand)),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(user.department?.name ?? '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColor.brand)),
          ),
          Expanded(flex: 2, child: _RoleBadge(role: user.role)),
          Expanded(
            flex: 2,
            child: StatusPill(
              user.isActive ? 'Active' : 'Inactive',
              color: user.isActive ? AppColor.success : AppColor.textMuted,
              background: user.isActive ? AppColor.successSoft : AppColor.surfaceMuted,
              dot: true,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.isOnline ? 'Mtandaoni' : Fmt.relative(user.lastSeenAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, size: 18),
              onSelected: (v) async {
                if (v == 'edit') {
                  showUserForm(context, ref, user: user);
                } else if (v == 'toggle') {
                  await ref.read(directoryRepositoryProvider).updateUser(user.id, {
                    'status': user.isActive ? 'inactive' : 'active',
                  });
                  ref.invalidate(usersProvider);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Hariri')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(user.isActive ? 'Zima akaunti' : 'Washa akaunti'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (role) {
      UserRole.admin => (AppColor.brand, AppColor.brandSoft, Icons.shield_outlined),
      UserRole.manager => (AppColor.accent, AppColor.accentSoft, Icons.workspace_premium_outlined),
      UserRole.staff => (AppColor.slate, AppColor.surfaceMuted, Icons.code_rounded),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: StatusPill(role.label, color: color, background: bg, icon: icon),
    );
  }
}

// ---------------------------------------------------------------------------
// Departments tab
// ---------------------------------------------------------------------------

class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);
    return departments.when(
      loading: () => const LoadingBlock(height: 200),
      error: (e, _) => ErrorBlock(message: '$e'),
      data: (list) => Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (var i = 0; i < list.length; i++)
            SizedBox(
              width: 280,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColor.departmentPalette[i % AppColor.departmentPalette.length]
                            .withValues(alpha: 0.14),
                        borderRadius: AppRadius.md,
                      ),
                      child: Icon(Icons.apartment_rounded,
                          size: 18,
                          color: AppColor
                              .departmentPalette[i % AppColor.departmentPalette.length]),
                    ),
                    Gap.md,
                    Text(list[i].name, style: Theme.of(context).textTheme.titleMedium),
                    if (list[i].description != null) ...[
                      Gap.xs,
                      Text(list[i].description!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    Gap.md,
                    Text('${list[i].usersCount ?? 0} wafanyakazi',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600, color: AppColor.slate)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roles tab
// ---------------------------------------------------------------------------

class _RolesTab extends StatelessWidget {
  const _RolesTab();

  static const _matrix = {
    'Kuona kazi zote za idara': [true, true, false],
    'Kutengeneza & kupangia kazi': [true, true, false],
    'Kuidhinisha / kurudisha kazi': [true, true, false],
    'Kuanza & kukamilisha kazi': [true, true, true],
    'Kusimamia watumiaji & idara': [true, false, false],
    'Kutuma ujumbe kwenye channels': [true, true, true],
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            color: AppColor.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('RUHUSA', style: Theme.of(context).textTheme.labelSmall)),
                for (final r in ['ADMIN', 'MANAGER', 'STAFF'])
                  Expanded(
                    child: Center(
                        child: Text(r, style: Theme.of(context).textTheme.labelSmall)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final entry in _matrix.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColor.border)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(entry.key)),
                  for (final allowed in entry.value)
                    Expanded(
                      child: Center(
                        child: Icon(
                          allowed ? Icons.check_circle_rounded : Icons.remove_rounded,
                          size: 18,
                          color: allowed ? AppColor.success : AppColor.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
