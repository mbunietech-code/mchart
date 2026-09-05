import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
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
      'department_id': _departmentId,
    };
    try {
      if (_isEdit) {
        if (_password.text.isNotEmpty) {
          body['password'] = _password.text;
          body['password_confirmation'] = _password.text;
        }
        await repo.updateUser(widget.user!.id, body);
      } else {
        body['password'] = _password.text;
        body['password_confirmation'] = _password.text;
        await repo.createUser(body);
      }
      ref.invalidate(usersProvider);
      if (mounted) Navigator.pop(context);
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
                  child: DropdownButtonFormField<UserRole>(
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
                    ? 'New password (optional)'
                    : 'Initial password',
              ),
              validator: (v) {
                if (_isEdit) return null;
                return (v == null || v.length < 8)
                    ? 'At least 8 characters'
                    : null;
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
