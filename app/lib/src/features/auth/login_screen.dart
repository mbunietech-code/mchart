import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/mchart_logo.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // One login for everyone — the backend returns the account's role and
      // the app routes/filters every screen from that, there is no separate
      // "manager login" or "staff login".
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _email.text.trim(),
            password: _password.text,
            deviceName: 'MChart Desktop',
          );
    } on ApiException catch (e) {
      setState(
        () => _error = e.isValidation
            ? (e.firstErrorFor('email') ?? e.message)
            : e.message,
      );
    } catch (_) {
      setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: AppRadius.xl,
                border: Border.all(color: AppColor.border),
                boxShadow: AppShadow.raised,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const MChartLogo(size: 40),
                        Gap.md,
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MChart',
                                style: t.titleLarge?.copyWith(fontSize: 18),
                              ),
                              Text(
                                'Mbunietech Workspace',
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap.xl,
                    Text('Sign in', style: t.titleLarge),
                    Gap.xs,
                    Text(
                      'Sign in to the Mbunietech communication and task workspace.',
                      style: t.bodySmall?.copyWith(
                        color: const Color(0xFF5A6B9C),
                      ),
                    ),
                    Gap.xl,
                    _FieldLabel('Email'),
                    Gap.xs,
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        hintText: 'you@mbunietech.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email address'
                          : null,
                    ),
                    Gap.md,
                    _FieldLabel('Password'),
                    Gap.xs,
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),
                    Gap.sm,
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? true),
                          ),
                        ),
                        Gap.xs,
                        Flexible(
                          child: Text(
                            'Remember me',
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showForgot(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[Gap.md, _ErrorBanner(_error!)],
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
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Sign in',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                    ),
                    Gap.md,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColor.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Gap.xs,
                        Flexible(
                          child: Text(
                            'All systems operational',
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColor.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap.md,
                    Text(
                      '© 2026 Mbunietech Technologies Limited. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: AppColor.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgot(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const _ForgotDialog());
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColor.textPrimary,
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColor.dangerSoft,
      borderRadius: AppRadius.md,
      border: Border.all(color: AppColor.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColor.danger,
        ),
        Gap.sm,
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColor.danger),
          ),
        ),
      ],
    ),
  );
}

class _ForgotDialog extends ConsumerStatefulWidget {
  const _ForgotDialog();
  @override
  ConsumerState<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends ConsumerState<_ForgotDialog> {
  final _email = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your email and we\'ll send you reset instructions.',
          ),
          Gap.md,
          TextField(
            controller: _email,
            decoration: const InputDecoration(hintText: 'Email address'),
          ),
          if (_message != null) ...[
            Gap.sm,
            Text(
              _message!,
              style: const TextStyle(fontSize: 12, color: AppColor.success),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await ref
                        .read(authControllerProvider.notifier)
                        .sendPasswordReset(_email.text.trim());
                    setState(
                      () => _message =
                          'If that account exists, instructions were sent.',
                    );
                  } catch (_) {
                    setState(
                      () =>
                          _message = 'Something went wrong. Please try again.',
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
