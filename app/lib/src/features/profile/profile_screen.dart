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
import 'avatar_crop_screen.dart';

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

  /// Photo options sheet: take / choose a new one, view or remove it.
  Future<void> _photoOptions(User user) async {
    final mobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mobile)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(mobile ? 'Choose from gallery' : 'Choose a picture'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (user.avatarUrl != null) ...[
              ListTile(
                leading: const Icon(Icons.visibility_rounded),
                title: const Text('View photo'),
                onTap: () => Navigator.pop(context, 'view'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColor.danger,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppColor.danger),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        return _pickPhoto(ImageSource.camera);
      case 'gallery':
        return _pickPhoto(ImageSource.gallery);
      case 'view':
        return _viewPhoto(user);
      case 'remove':
        return _removePhoto();
    }
  }

  void _viewPhoto(User user) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(user.name),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.network(user.avatarUrl!, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    final cropped = await AvatarCropScreen.open(context, bytes);
    if (cropped == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      _apply(
        await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>(
              '/me/avatar',
              data: FormData.fromMap({
                'avatar': MultipartFile.fromBytes(
                  cropped,
                  filename: 'avatar.png',
                ),
              }),
            ),
      );
      _toast('Profile photo updated');
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
                  child: GestureDetector(
                    onTap: _uploading ? null : () => _photoOptions(user),
                    child: Stack(
                      children: [
                        AppAvatar.forUser(user, size: 128),
                        if (_uploading)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            tooltip: 'Change photo',
                            onPressed: _uploading
                                ? null
                                : () => _photoOptions(user),
                            icon: const Icon(Icons.photo_camera_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap.sm,
                Center(
                  child: TextButton(
                    onPressed: _uploading ? null : () => _photoOptions(user),
                    child: Text(
                      user.avatarUrl == null ? 'Add photo' : 'Change photo',
                    ),
                  ),
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
