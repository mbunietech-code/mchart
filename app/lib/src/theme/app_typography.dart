import 'package:flutter/material.dart';

import 'app_color.dart';

/// MChart type scale. The design calls for Inter; when an `Inter` asset is
/// bundled (see pubspec `fonts:`) it is used, otherwise the platform sans-serif
/// stack renders (Segoe UI / SF Pro / Roboto) which is visually close.
abstract final class AppType {
  static const fontFamily = 'Inter';
  static const _fallback = <String>[
    'Segoe UI',
    'SF Pro Text',
    'Roboto',
    'sans-serif',
  ];

  static TextTheme textTheme(TextTheme base) {
    final t = base.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: _fallback,
      bodyColor: AppColor.textPrimary,
      displayColor: AppColor.textPrimary,
    );
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColor.textPrimary,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColor.textPrimary,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColor.textPrimary,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColor.textPrimary,
      ),
      titleSmall: t.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColor.textPrimary,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: AppColor.textPrimary,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: AppColor.textSecondary,
      ),
      bodySmall: t.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AppColor.textSecondary,
      ),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColor.textPrimary,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColor.textMuted,
      ),
    );
  }

  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColor.breadcrumb,
  );

  static const stat = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColor.textPrimary,
  );
}
