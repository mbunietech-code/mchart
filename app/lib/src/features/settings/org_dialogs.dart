import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../directory/directory_repository.dart';

/// Add or rename a department (Settings > Departments).
Future<void> showDepartmentForm(
  BuildContext context,
  WidgetRef ref, {
  Department? department,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DepartmentDialog(department: department),
);

class _DepartmentDialog extends ConsumerStatefulWidget {
  const _DepartmentDialog({this.department});
  final Department? department;

  @override
  ConsumerState<_DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends ConsumerState<_DepartmentDialog> {
  late final _name = TextEditingController(text: widget.department?.name);
  late final _description = TextEditingController(
    text: widget.department?.description,
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return setState(() => _error = 'Enter a name');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    };
    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (widget.department == null) {
        await repo.createDepartment(body);
      } else {
        await repo.updateDepartment(widget.department!.id, body);
      }
      ref.invalidate(departmentsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.firstErrorFor('name') ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.department == null ? 'Add department' : 'Edit department',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          Gap.md,
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          if (_error != null) ...[
            Gap.sm,
            Text(_error!, style: const TextStyle(color: AppColor.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Add or edit a job title and its permission level (Settings > Roles).
Future<void> showRoleForm(
  BuildContext context,
  WidgetRef ref, {
  AppRole? role,
}) => showDialog<void>(
  context: context,
  builder: (_) => _RoleDialog(role: role),
);

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({this.role});
  final AppRole? role;

  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late final _label = TextEditingController(text: widget.role?.label);
  late UserRole _level = widget.role?.level ?? UserRole.staff;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      return setState(() => _error = 'Enter a title');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {'label': _label.text.trim(), 'level': _level.name};
    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (widget.role == null) {
        await repo.createRole(body);
      } else {
        await repo.updateRole(widget.role!.id, body);
      }
      ref.invalidate(rolesProvider);
      ref.invalidate(usersProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.firstErrorFor('label') ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builtIn = widget.role?.builtIn ?? false;
    return AlertDialog(
      title: Text(widget.role == null ? 'Add role' : 'Edit role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Accountant, Designer, Team Lead',
            ),
          ),
          Gap.md,
          DropdownButtonFormField<UserRole>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: 'Permission level'),
            items: [
              for (final r in UserRole.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: builtIn
                ? null
                : (v) => setState(() => _level = v ?? UserRole.staff),
          ),
          Gap.sm,
          Text(
            builtIn
                ? 'Built-in roles keep their permission level.'
                : 'People with this title get exactly the permissions of the level (see the table).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            Gap.sm,
            Text(_error!, style: const TextStyle(color: AppColor.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Confirm, then delete; the server explains when it refuses.
Future<void> confirmDelete(
  BuildContext context, {
  required String title,
  required Future<void> Function() action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
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
    await action();
    messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
