import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/mchart_logo.dart';
import 'auth_controller.dart';

/// First sign-in with a temporary password: the router sends the user here
/// and nowhere else until they pick their own.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(current: _current.text, next: _next.text);
      // The router moves on to Chats once the flag clears.
    } on ApiException catch (e) {
      setState(
        () => _error = e.isValidation
            ? (e.firstErrorFor('current_password') ??
                  e.firstErrorFor('password') ??
                  e.message)
            : e.message,
      );
    } catch (_) {
      setState(() => _error = 'Could not change the password. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mirrors the server's Password::defaults(): 8+ characters.
  String? _validateNew(String? v) {
    if (v == null || v.length < 8) return 'Use at least 8 characters';
    if (v == _current.text) return 'Choose a different password';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);

    InputDecoration field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: AppRadius.xl,
                border: Border.all(color: AppColor.border),
                boxShadow: AppShadow.raised,
              ),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: MChartLogo(size: 40),
                      ),
                      Gap.lg,
                      Text('Choose your password', style: t.titleLarge),
                      Gap.xs,
                      Text(
                        'Welcome${user != null ? ', ${user.name.split(' ').first}' : ''}! '
                        'You signed in with a temporary password. Set your own to start chatting.',
                        style: t.bodySmall?.copyWith(
                          color: const Color(0xFF5A6B9C),
                        ),
                      ),
                      Gap.xl,
                      TextFormField(
                        controller: _current,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: field(
                          'Temporary password (from the email)',
                          Icons.key_outlined,
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter the temporary password'
                            : null,
                      ),
                      Gap.md,
                      TextFormField(
                        controller: _next,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: field(
                          'New password',
                          Icons.lock_outline_rounded,
                        ),
                        validator: _validateNew,
                      ),
                      Gap.md,
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: field(
                          'Confirm new password',
                          Icons.lock_outline_rounded,
                        ),
                        validator: (v) =>
                            v != _next.text ? 'Passwords do not match' : null,
                      ),
                      if (_error != null) ...[
                        Gap.md,
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColor.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      Gap.lg,
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save and continue'),
                      ),
                      Gap.sm,
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .logout(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
