import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_color.dart';
import '../../widgets/mchart_logo.dart';
import '../auth/auth_controller.dart';
import 'app_lock.dart';

const pinLength = 4;

/// Four dots and a number pad; also takes digits and Backspace from a
/// keyboard (Windows). Calls [onComplete] once [pinLength] digits are in and
/// clears itself when [error] changes.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.error,
    this.footer,
  });
  final String title;
  final String? error;
  final ValueChanged<String> onComplete;
  final Widget? footer;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  final _focus = FocusNode();

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.error != widget.error || old.title != widget.title) _pin = '';
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _add(String d) {
    if (_pin.length >= pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == pinLength) {
      final pin = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _pin = '');
        widget.onComplete(pin);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _add(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget key(String d) => _Key(label: d, onTap: () => _add(d));
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: text.titleMedium),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pinLength; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColor.brand : null,
                    border: Border.all(color: AppColor.brand, width: 1.6),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(
                widget.error ?? '',
                style: text.bodySmall?.copyWith(color: AppColor.danger),
              ),
            ),
          ),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final d in row) key(d)],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 84),
              key('0'),
              SizedBox(
                width: 84,
                height: 72,
                child: IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
          if (widget.footer != null) ...[
            const SizedBox(height: 8),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: AppColor.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 60,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Covers the whole app until the PIN is entered.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;
  int _tries = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MChartLogo(size: 56),
                const SizedBox(height: 12),
                Text(
                  'MChat is locked',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                PinPad(
                  title: 'Enter your PIN',
                  error: _error,
                  onComplete: (pin) {
                    if (ref.read(appLockProvider.notifier).unlock(pin)) return;
                    setState(() {
                      _tries++;
                      _error = 'Wrong PIN ($_tries)';
                    });
                  },
                  footer: TextButton(
                    onPressed: () async {
                      // Forgot PIN: sign out; signing back in with the
                      // password proves who it is.
                      await ref.read(appLockProvider.notifier).clearPin();
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                    child: const Text('Forgot PIN? Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Set or change the PIN: enter it twice. Returns true when saved.
Future<bool?> showSetPinDialog(BuildContext context, WidgetRef ref) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const Dialog(
      child: Padding(padding: EdgeInsets.all(20), child: _SetPin()),
    ),
  );
}

class _SetPin extends ConsumerStatefulWidget {
  const _SetPin();

  @override
  ConsumerState<_SetPin> createState() => _SetPinState();
}

class _SetPinState extends ConsumerState<_SetPin> {
  String? _first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return PinPad(
      title: _first == null ? 'Choose a 4-digit PIN' : 'Enter the PIN again',
      error: _error,
      onComplete: (pin) async {
        if (_first == null) {
          setState(() {
            _first = pin;
            _error = null;
          });
          return;
        }
        if (pin != _first) {
          setState(() {
            _first = null;
            _error = 'PINs did not match, start again';
          });
          return;
        }
        await ref.read(appLockProvider.notifier).setPin(pin);
        if (context.mounted) Navigator.of(context).pop(true);
      },
      footer: TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
    );
  }
}
