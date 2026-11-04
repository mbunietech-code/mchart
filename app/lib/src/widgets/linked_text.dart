import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Message text with web links, emails and phone numbers made tappable.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {super.key, required this.style, this.linkColor});
  final String text;
  final TextStyle style;
  final Color? linkColor;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  // Order matters: emails before bare domains so "a@b.com" isn't a link to b.com.
  static final _pattern = RegExp(
    r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})'
    r'|((?:https?://|www\.)[^\s<>"]+'
    r'|\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:com|net|org|tz|co|io|tech|app|dev|info|me|africa)(?:/[^\s<>"]*)?)'
    r'|(\+?\d[\d -]{8,}\d)',
  );

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Uri? _target(Match m) {
    if (m[1] != null) return Uri(scheme: 'mailto', path: m[1]);
    if (m[2] != null) {
      var url = m[2]!.replaceFirst(RegExp(r'[.,!?;:)\]]+$'), '');
      if (!url.startsWith('http')) url = 'https://$url';
      return Uri.tryParse(url);
    }
    return Uri(scheme: 'tel', path: m[3]!.replaceAll(RegExp(r'[ -]'), ''));
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      final matched = m[0]!;
      // Keep trailing punctuation out of links ("see example.com.").
      final trimmed = matched.replaceFirst(RegExp(r'[.,!?;:)\]]+$'), '');
      final end = m.start + trimmed.length;
      final uri = _target(m);
      if (uri == null || trimmed.isEmpty) continue;
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final r = TapGestureRecognizer()
        ..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication);
      _recognizers.add(r);
      spans.add(
        TextSpan(
          text: text.substring(m.start, end),
          recognizer: r,
          mouseCursor: SystemMouseCursors.click,
          style: TextStyle(
            color: widget.linkColor ?? Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
