import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../auth/auth_controller.dart';

/// The signed-in user's own photo, name, phone and password.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _name = TextEditingController(
    text: ref.read(currentUserProvider)?.name,
  );
  late final _phone = TextEditingController(
    text: ref.read(currentUserProvider)?.phone,
  );
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _apply(Map<String, dynamic> json) => ref
      .read(authControllerProvider.notifier)
      .updateUser(User.fromJson(json['data'] as Map<String, dynamic>));

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _toast('Name cannot be empty');
    setState(() => _saving = true);
    try {
      _apply(
        await ref
            .read(apiClientProvider)
            .patch<Map<String, dynamic>>(
              '/me',
              data: {'name': _name.text.trim(), 'phone': _phone.text.trim()},
            ),
      );
      _toast('Profile saved');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (x == null) return;
    setState(() => _uploading = true);
    try {
      _apply(
        await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>(
              '/me/avatar',
              data: FormData.fromMap({
                'avatar': await MultipartFile.fromFile(
                  x.path,
                  filename: x.name,
                ),
              }),
            ),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    try {
      _apply(
        await ref
            .read(apiClientProvider)
            .delete<Map<String, dynamic>>('/me/avatar'),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('My profile', style: t.headlineSmall),
                Gap.xl,
                Center(
                  child: Stack(
                    children: [
                      AppAvatar.forUser(user, size: 104),
                      if (_uploading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Change photo',
                          onPressed: _uploading ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_camera_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                if (user.avatarUrl != null)
                  TextButton(
                    onPressed: _uploading ? null : _removePhoto,
                    child: const Text('Remove photo'),
                  ),
                Gap.lg,
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                Gap.md,
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                Gap.md,
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: user.email),
                  decoration: const InputDecoration(
                    labelText: 'Email (your username)',
                  ),
                ),
                Gap.lg,
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
                Gap.xl,
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _ChangePasswordDialog(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColor.danger,
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(color: AppColor.danger),
                  ),
                  onTap: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) {
      return setState(() => _error = 'New password: at least 8 characters');
    }
    if (_next.text != _confirm.text) {
      return setState(() => _error = 'Passwords do not match');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed')));
    } on ApiException catch (e) {
      setState(
        () => _error =
            e.firstErrorFor('current_password') ??
            e.firstErrorFor('password') ??
            e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          Gap.sm,
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          Gap.sm,
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
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
          onPressed: _busy ? null : _submit,
          child: const Text('Change'),
        ),
      ],
    );
  }
}
