import 'package:flutter/material.dart';

import '../theme/app_color.dart';

/// Soft colored pill used for status, roles, counts, trends.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.color = AppColor.textSecondary,
    this.background,
    this.icon,
    this.dot = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dot;
  final bool dense;

  factory StatusPill.success(String label, {IconData? icon}) => StatusPill(
    label,
    color: AppColor.success,
    background: AppColor.successSoft,
    icon: icon,
  );
  factory StatusPill.warning(String label, {IconData? icon}) => StatusPill(
    label,
    color: AppColor.warning,
    background: AppColor.warningSoft,
    icon: icon,
  );
  factory StatusPill.danger(String label, {IconData? icon}) => StatusPill(
    label,
    color: AppColor.danger,
    background: AppColor.dangerSoft,
    icon: icon,
  );
  factory StatusPill.brand(String label, {IconData? icon}) => StatusPill(
    label,
    color: AppColor.brand,
    background: AppColor.brandSoft,
    icon: icon,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green / grey "live" indicator with a pulsing dot.
class LivePill extends StatelessWidget {
  const LivePill({
    super.key,
    required this.online,
    this.onlineLabel = 'Live',
    this.offlineLabel = 'Offline',
  });
  final bool online;
  final String onlineLabel;
  final String offlineLabel;

  @override
  Widget build(BuildContext context) => StatusPill(
    online ? onlineLabel : offlineLabel,
    color: online ? AppColor.success : AppColor.textMuted,
    background: online ? AppColor.successSoft : AppColor.surfaceMuted,
    dot: true,
  );
}

/// Up/down trend chip ("↗ +8%").
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.delta, this.suffix = '%'});
  final num delta;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive ? AppColor.success : AppColor.danger;
    return StatusPill(
      '${positive ? '+' : ''}$delta$suffix',
      color: color,
      background: positive ? AppColor.successSoft : AppColor.dangerSoft,
      icon: positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      dense: true,
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.color = AppColor.brand});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
