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

  static const _demo = {
    'Manager': 'manager@mbunietech.com',
    'Staff': 'dev1@mbunietech.com',
    'Admin': 'admin@mbunietech.com',
  };

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
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
            deviceName: 'MChart Desktop',
          );
    } on ApiException catch (e) {
      setState(() => _error = e.isValidation
          ? (e.firstErrorFor('email') ?? e.message)
          : e.message);
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
                              Text('MChart',
                                  style: t.titleLarge?.copyWith(fontSize: 18)),
                              Text('Mbunie Chart — MbuniTech Workspace',
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall?.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap.xl,
                    Text('Ingia Kazini', style: t.titleLarge),
                    Gap.xs,
                    Text(
                      'Ingia kwenye mfumo wa mawasiliano na usimamizi wa kazi wa MbuniTech.',
                      style: t.bodySmall?.copyWith(color: const Color(0xFF5A6B9C)),
                    ),
                    Gap.lg,
                    Text('Akaunti za Mfano (Quick Switch)',
                        style: t.labelSmall),
                    Gap.sm,
                    _DemoSwitcher(
                      onPick: (email) {
                        _email.text = email;
                        _password.text = 'password';
                      },
                      accounts: _demo,
                    ),
                    Gap.lg,
                    _FieldLabel('Barua Pepe'),
                    Gap.xs,
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        hintText: 'mfano. juma@mbunietech.co.tz',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Weka barua pepe sahihi'
                          : null,
                    ),
                    Gap.md,
                    _FieldLabel('Nenosiri'),
                    Gap.xs,
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Weka nenosiri' : null,
                    ),
                    Gap.sm,
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _remember,
                            onChanged: (v) => setState(() => _remember = v ?? true),
                          ),
                        ),
                        Gap.xs,
                        Flexible(
                          child: Text('Nikumbuke',
                              overflow: TextOverflow.ellipsis, style: t.bodySmall),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showForgot(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Umesahau nenosiri?',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      Gap.md,
                      _ErrorBanner(_error!),
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
                                strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text('Ingia Kazini',
                                      overflow: TextOverflow.ellipsis),
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
                              color: AppColor.success, shape: BoxShape.circle),
                        ),
                        Gap.xs,
                        Flexible(
                          child: Text('Mfumo ipo hewani kikamilifu (99.98%)',
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 11, color: AppColor.success)),
                        ),
                      ],
                    ),
                    Gap.md,
                    Text(
                      '© 2026 MbuniTech Technologies Limited. Haki zote zimehifadhiwa.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(fontSize: 10.5, color: AppColor.textMuted),
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
    showDialog<void>(
      context: context,
      builder: (_) => const _ForgotDialog(),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
      );
}

class _DemoSwitcher extends StatefulWidget {
  const _DemoSwitcher({required this.onPick, required this.accounts});
  final void Function(String email) onPick;
  final Map<String, String> accounts;

  @override
  State<_DemoSwitcher> createState() => _DemoSwitcherState();
}

class _DemoSwitcherState extends State<_DemoSwitcher> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.accounts.entries.toList();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColor.surfaceMuted,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selected = i);
                  widget.onPick(entries[i].value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selected == i ? AppColor.surface : Colors.transparent,
                    borderRadius: AppRadius.sm,
                    boxShadow: _selected == i ? AppShadow.segment : null,
                  ),
                  child: Text(
                    entries[i].key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selected == i
                          ? AppColor.textPrimary
                          : AppColor.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColor.danger),
            Gap.sm,
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 12, color: AppColor.danger)),
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
      title: const Text('Rejesha Nenosiri'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weka barua pepe yako na tutakutumia maelekezo.'),
          Gap.md,
          TextField(
            controller: _email,
            decoration: const InputDecoration(hintText: 'barua pepe'),
          ),
          if (_message != null) ...[
            Gap.sm,
            Text(_message!,
                style: const TextStyle(fontSize: 12, color: AppColor.success)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Funga'),
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
                    setState(() => _message =
                        'Kama akaunti ipo, maelekezo yametumwa.');
                  } catch (_) {
                    setState(() => _message = 'Imeshindikana. Jaribu tena.');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Tuma'),
        ),
      ],
    );
  }
}
