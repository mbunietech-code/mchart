import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../directory/directory_repository.dart';

Future<void> showUserForm(BuildContext context, WidgetRef ref, {User? user}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _UserForm(user: user),
      ),
    ),
  );
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({this.user});
  final User? user;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  final _password = TextEditingController();
  late UserRole _role = widget.user?.role ?? UserRole.staff;
  late int? _roleId = widget.user?.roleId;
  late int? _departmentId = widget.user?.departmentId;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(directoryRepositoryProvider);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'role': _role.name,
      'role_id': ?_roleId,
      'department_id': _departmentId,
    };
    try {
      if (_isEdit) {
        if (_password.text.isNotEmpty) {
          body['password'] = _password.text;
          body['password_confirmation'] = _password.text;
        }
        await repo.updateUser(widget.user!.id, body);
        ref.invalidate(usersProvider);
        if (mounted) Navigator.pop(context);
      } else {
        // Empty = the server generates a temporary password and emails it.
        if (_password.text.isNotEmpty) {
          body['password'] = _password.text;
          body['password_confirmation'] = _password.text;
        }
        final created = await repo.createUser(body);
        ref.invalidate(usersProvider);
        if (!mounted) return;
        final nav = Navigator.of(context);
        nav.pop();
        await showDialog<void>(
          context: nav.context,
          builder: (_) => InvitedDialog(created: created),
        );
      }
    } on ApiException catch (e) {
      setState(
        () => _error = e.errors?.values.firstOrNull?.firstOrNull ?? e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit User' : 'Invite New User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gap.lg,
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            Gap.md,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email address'
                  : null,
            ),
            Gap.md,
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            Gap.md,
            Row(
              children: [
                Expanded(
                  child: ref
                      .watch(rolesProvider)
                      .maybeWhen(
                        data: (roles) => DropdownButtonFormField<int>(
                          initialValue: roles.any((r) => r.id == _roleId)
                              ? _roleId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [
                            for (final r in roles)
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  r.builtIn
                                      ? r.label
                                      : '${r.label} · ${r.level.label}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (v) => v == null ? 'Pick a role' : null,
                          onChanged: (v) => setState(() {
                            _roleId = v;
                            _role =
                                roles
                                    .where((r) => r.id == v)
                                    .firstOrNull
                                    ?.level ??
                                UserRole.staff;
                          }),
                        ),
                        orElse: () => DropdownButtonFormField<UserRole>(
                          initialValue: _role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [
                            for (final r in UserRole.values)
                              DropdownMenuItem(value: r, child: Text(r.label)),
                          ],
                          onChanged: (v) =>
                              setState(() => _role = v ?? UserRole.staff),
                        ),
                      ),
                ),
                Gap.md,
                Expanded(
                  child: departments.maybeWhen(
                    data: (list) => DropdownButtonFormField<int?>(
                      initialValue: _departmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final d in list)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => setState(() => _departmentId = v),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            Gap.md,
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEdit
                    ? 'New temporary password (optional)'
                    : 'Temporary password (optional)',
                helperText: _isEdit
                    ? 'They will be asked to change it at next sign-in'
                    : 'Leave empty to generate one. It is emailed with the app link, and they must change it at first sign-in.',
                helperMaxLines: 3,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                return v.length < 8 ? 'At least 8 characters' : null;
              },
            ),
            if (_error != null) ...[
              Gap.md,
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            Gap.xl,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Gap.sm,
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy ? 'Saving...' : (_isEdit ? 'Save' : 'Invite'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once after inviting: whether the email went out, and the
/// temporary password so the admin can pass it on if it didn't.
class InvitedDialog extends StatelessWidget {
  const InvitedDialog({required this.created});
  final CreatedUser created;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sent = created.invitationSent;
    return AlertDialog(
      icon: Icon(
        sent ? Icons.mark_email_read_outlined : Icons.info_outline_rounded,
        color: sent ? AppColor.success : AppColor.accent,
      ),
      title: Text('${created.user.name} invited'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sent
                ? 'An email with the app download link and sign-in details was sent to ${created.user.email}.'
                : 'The invitation email could not be sent. Share these sign-in details with them directly:',
          ),
          if (created.temporaryPassword != null) ...[
            Gap.md,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColor.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('Username: ${created.user.email}'),
                  Gap.xs,
                  SelectableText(
                    'Temporary password: ${created.temporaryPassword}',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Gap.sm,
            Text(
              'They will be asked to choose their own password at first sign-in. This password is not shown again.',
              style: t.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
