import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'primitives.dart';

/// Breadcrumb eyebrow + H1 + supporting copy, with optional trailing actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.breadcrumb,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String breadcrumb;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 720;
        // Phones: just the title, so the page content gets the height.
        final phone = c.maxWidth < 600;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!phone) ...[Eyebrow(breadcrumb), Gap.sm],
            Text(
              title,
              style: phone
                  ? Theme.of(context).textTheme.headlineSmall
                  : Theme.of(context).textTheme.displaySmall,
            ),
            if (subtitle != null && !phone) ...[
              Gap.xs,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        );

        if (actions.isEmpty) return text;

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              Gap.lg,
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            phone ? Gap.md : Gap.lg,
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      },
    );
  }
}
