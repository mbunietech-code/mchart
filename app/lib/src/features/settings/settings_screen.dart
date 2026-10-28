import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
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
import 'org_dialogs.dart';
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
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  breadcrumb: 'Operations • Organization Management',
                  title: 'Admin Settings',
                  subtitle:
                      'Manage users, departments, and roles across the Mbunietech workspace.',
                  actions: [
                    if (isAdmin && _tab == 0)
                      FilledButton.icon(
                        onPressed: () => showUserForm(context, ref),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: const Text('Invite User'),
                      ),
                    if (isAdmin && _tab == 1)
                      FilledButton.icon(
                        onPressed: () => showDepartmentForm(context, ref),
                        icon: const Icon(Icons.add_business_rounded, size: 18),
                        label: const Text('Add Department'),
                      ),
                    if (isAdmin && _tab == 2)
                      FilledButton.icon(
                        onPressed: () => showRoleForm(context, ref),
                        icon: const Icon(
                          Icons.add_moderator_outlined,
                          size: 18,
                        ),
                        label: const Text('Add Role'),
                      ),
                  ],
                ),
                Gap.xl,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ref
                        .watch(usersProvider)
                        .maybeWhen(
                          data: (p) => StatChip(
                            icon: Icons.groups_outlined,
                            value: '${p.total}',
                            label: 'Staff',
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                    departments.maybeWhen(
                      data: (d) => StatChip(
                        icon: Icons.apartment_rounded,
                        value: '${d.length}',
                        label: 'Departments',
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                Gap.xl,
                _Tabs(index: _tab, onChanged: (i) => setState(() => _tab = i)),
                Gap.lg,
                if (!isAdmin)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Admin Only',
                      message: 'Only an Admin can access these settings.',
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

  static const _labels = ['Users', 'Departments', 'Roles & Permissions'];

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
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
            child: LayoutBuilder(
              builder: (context, c) {
                final search = TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email, or department...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                  onChanged: (v) => ref.read(userQueryProvider.notifier).state =
                      query.copyWith(search: v, page: 1),
                );
                final filters = [
                  departments.maybeWhen(
                    data: (list) => _FilterDropdown<int?>(
                      value: query.departmentId,
                      hint: 'All Departments',
                      items: {
                        null: 'All Departments',
                        for (final d in list) d.id: d.name,
                      },
                      onChanged: (v) =>
                          ref.read(userQueryProvider.notifier).state = query
                              .copyWith(departmentId: v, page: 1),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  _FilterDropdown<String?>(
                    value: query.role,
                    hint: 'All Roles',
                    items: const {
                      null: 'All Roles',
                      'admin': 'Admin',
                      'manager': 'Manager',
                      'staff': 'Staff',
                    },
                    onChanged: (v) =>
                        ref.read(userQueryProvider.notifier).state = query
                            .copyWith(role: v, page: 1),
                  ),
                ];

                if (c.maxWidth > 620) {
                  return Row(
                    children: [
                      Expanded(child: search),
                      Gap.md,
                      filters[0],
                      Gap.sm,
                      filters[1],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    Gap.sm,
                    Wrap(spacing: 8, runSpacing: 8, children: filters),
                  ],
                );
              },
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
                if (page.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No users found',
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth > 640) {
                        return Column(
                          children: [
                            const _UserHeaderRow(),
                            const Divider(height: 1),
                            for (final u in page.items) _UserRow(user: u),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (final u in page.items) _UserCard(user: u),
                        ],
                      );
                    },
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${page.items.length} of ${page.total}',
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
                      Text(
                        '${page.currentPage} / ${page.lastPage}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColor.textPrimary),
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
      child: Text(
        s.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
    return Container(
      color: AppColor.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          cell('Staff', 4),
          cell('Department', 2),
          cell('Role', 2),
          cell('Status', 2),
          cell('Last Seen', 2),
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
                      Text(
                        user.name,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: AppColor.brand),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.department?.name ?? '—',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColor.brand),
            ),
          ),
          Expanded(flex: 2, child: _RoleBadge(role: user.role, title: user.roleLabel)),
          Expanded(
            flex: 2,
            child: StatusPill(
              user.isActive ? 'Active' : 'Inactive',
              color: user.isActive ? AppColor.success : AppColor.textMuted,
              background: user.isActive
                  ? AppColor.successSoft
                  : AppColor.surfaceMuted,
              dot: true,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.isOnline ? 'Online' : Fmt.relative(user.lastSeenAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
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
                  await ref.read(directoryRepositoryProvider).updateUser(
                    user.id,
                    {'status': user.isActive ? 'inactive' : 'active'},
                  );
                  ref.invalidate(usersProvider);
                } else if (v == 'resend' && context.mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final created = await ref
                        .read(directoryRepositoryProvider)
                        .resendInvitation(user);
                    if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => InvitedDialog(created: created),
                      );
                    }
                  } on ApiException catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  }
                } else if (v == 'delete' && context.mounted) {
                  await confirmDeleteUser(context, ref, user);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    user.isActive ? 'Deactivate account' : 'Activate account',
                  ),
                ),
                if (user.mustChangePassword)
                  const PopupMenuItem(
                    value: 'resend',
                    child: Text('Resend invitation'),
                  ),
                if (user.id != ref.read(currentUserProvider)?.id)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete permanently',
                      style: TextStyle(color: AppColor.danger),
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

/// Narrow-screen stand-in for `_UserHeaderRow` + `_UserRow`: the same info,
/// stacked as a card instead of squeezed into a 5-column table.
class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar.forUser(user, size: 36),
              Gap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: AppColor.brand),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                onSelected: (v) async {
                  if (v == 'edit') {
                    showUserForm(context, ref, user: user);
                  } else if (v == 'toggle') {
                    await ref.read(directoryRepositoryProvider).updateUser(
                      user.id,
                      {'status': user.isActive ? 'inactive' : 'active'},
                    );
                    ref.invalidate(usersProvider);
                  } else if (v == 'resend' && context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final created = await ref
                          .read(directoryRepositoryProvider)
                          .resendInvitation(user);
                      if (context.mounted) {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => InvitedDialog(created: created),
                        );
                      }
                    } on ApiException catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  } else if (v == 'delete' && context.mounted) {
                    await confirmDeleteUser(context, ref, user);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      user.isActive ? 'Deactivate account' : 'Activate account',
                    ),
                  ),
                  if (user.mustChangePassword)
                    const PopupMenuItem(
                      value: 'resend',
                      child: Text('Resend invitation'),
                    ),
                  if (user.id != ref.read(currentUserProvider)?.id)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete permanently',
                        style: TextStyle(color: AppColor.danger),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Gap.sm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RoleBadge(role: user.role, title: user.roleLabel),
              StatusPill(
                user.isActive ? 'Active' : 'Inactive',
                color: user.isActive ? AppColor.success : AppColor.textMuted,
                background: user.isActive
                    ? AppColor.successSoft
                    : AppColor.surfaceMuted,
                dot: true,
              ),
              if (user.department != null)
                StatusPill(
                  user.department!.name,
                  color: AppColor.brand,
                  background: AppColor.brandSoft,
                ),
              StatusPill(
                user.isOnline ? 'Online' : Fmt.relative(user.lastSeenAt),
                color: AppColor.textSecondary,
                background: AppColor.surfaceMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.title});
  final UserRole role;

  /// Job title; coloured by its permission level.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (role) {
      UserRole.admin => (
        AppColor.brand,
        AppColor.brandSoft,
        Icons.shield_outlined,
      ),
      UserRole.manager => (
        AppColor.accent,
        AppColor.accentSoft,
        Icons.workspace_premium_outlined,
      ),
      UserRole.staff => (
        AppColor.slate,
        AppColor.surfaceMuted,
        Icons.code_rounded,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: StatusPill(
        title ?? role.label,
        color: color,
        background: bg,
        icon: icon,
      ),
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
                        color: AppColor
                            .departmentPalette[i %
                                AppColor.departmentPalette.length]
                            .withValues(alpha: 0.14),
                        borderRadius: AppRadius.md,
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 18,
                        color:
                            AppColor.departmentPalette[i %
                                AppColor.departmentPalette.length],
                      ),
                    ),
                    Gap.md,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            list[i].name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                          onSelected: (v) {
                            if (v == 'edit') {
                              showDepartmentForm(
                                context,
                                ref,
                                department: list[i],
                              );
                            } else {
                              confirmDelete(
                                context,
                                title: 'Delete ${list[i].name}?',
                                action: () async {
                                  await ref
                                      .read(directoryRepositoryProvider)
                                      .deleteDepartment(list[i].id);
                                  ref.invalidate(departmentsProvider);
                                },
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: AppColor.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (list[i].description != null) ...[
                      Gap.xs,
                      Text(
                        list[i].description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    Gap.md,
                    Text(
                      '${list[i].usersCount ?? 0} staff',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColor.slate,
                      ),
                    ),
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

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  static const _matrix = {
    'View all department tasks': [true, true, false],
    'Create & assign tasks': [true, true, false],
    'Approve / return tasks': [true, true, false],
    'Start & complete tasks': [true, true, true],
    'Manage users & departments': [true, false, false],
    'Post messages in channels': [true, true, true],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: roles.when(
            loading: () => const LoadingBlock(height: 120),
            error: (e, _) => ErrorBlock(message: '$e'),
            data: (list) => Column(
              children: [
                for (final r in list)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(r.label),
                    subtitle: Text(
                      '${r.level.label} level · ${r.usersCount} '
                      '${r.usersCount == 1 ? 'person' : 'people'}'
                      '${r.builtIn ? ' · built-in' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') {
                          showRoleForm(context, ref, role: r);
                        } else {
                          confirmDelete(
                            context,
                            title: 'Delete the ${r.label} role?',
                            action: () async {
                              await ref
                                  .read(directoryRepositoryProvider)
                                  .deleteRole(r.id);
                              ref.invalidate(rolesProvider);
                            },
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (!r.builtIn)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: AppColor.danger),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Gap.lg,
        Text(
          'What each permission level can do',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Gap.sm,
        _permissionMatrix(context),
      ],
    );
  }

  Widget _permissionMatrix(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // A horizontal scroll gives its child unbounded width, so the rows'
        // Expanded cells need a fixed width: the card's width, but never
        // narrower than the table can be read at (phones scroll sideways).
        child: SizedBox(
          width: math.max(MediaQuery.sizeOf(context).width - 56, 520),
          child: Column(
            children: [
              Container(
                color: AppColor.surfaceMuted,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'PERMISSION',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    for (final r in ['ADMIN', 'MANAGER', 'STAFF'])
                      Expanded(
                        child: Center(
                          child: Text(
                            r,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final entry in _matrix.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                              allowed
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_rounded,
                              size: 18,
                              color: allowed
                                  ? AppColor.success
                                  : AppColor.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms, then permanently deletes an unused account. The server
/// refuses accounts with history and says why; that message is shown.
Future<void> confirmDeleteUser(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Delete ${user.name}?'),
      content: Text(
        'This permanently removes ${user.email} so the email can be invited again. '
        'It only works for accounts that have not sent messages or worked on tasks; '
        'for anyone else, use Deactivate instead.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColor.danger),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(directoryRepositoryProvider).deleteUserPermanently(user.id);
    ref.invalidate(usersProvider);
    messenger.showSnackBar(SnackBar(content: Text('${user.name} deleted')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not delete the user. Try again.')),
    );
  }
}
