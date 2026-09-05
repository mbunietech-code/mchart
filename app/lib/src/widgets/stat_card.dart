import 'package:flutter/material.dart';

import '../theme/app_color.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primitives.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.badge,
    this.footLabel,
    this.footValue,
  });

  final String label;
  final String value;
  final String? caption;
  final Widget? badge;
  final String? footLabel;
  final Widget? footValue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(label)),
              if (badge != null) badge!,
            ],
          ),
          Gap.md,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.stat),
              if (caption != null) ...[
                Gap.sm,
                Expanded(
                  child: Text(
                    caption!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          if (footLabel != null || footValue != null) ...[
            Gap.md,
            const Divider(height: 1),
            Gap.sm,
            Row(
              children: [
                Expanded(
                  child: Text(
                    footLabel ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
                if (footValue != null) footValue!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact horizontal stat chip (as used on the Settings header).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColor.brandSoft,
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, size: 18, color: AppColor.brand),
          ),
          Gap.md,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Gap.xs,
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  if (hint != null) ...[
                    Gap.xs,
                    Text(
                      hint!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
