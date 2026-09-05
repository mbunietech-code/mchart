import 'package:flutter/material.dart';

import 'app_color.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColor.brand,
        onPrimary: AppColor.textOnBrand,
        secondary: AppColor.navy,
        surface: AppColor.surface,
        onSurface: AppColor.textPrimary,
        error: AppColor.danger,
        outline: AppColor.border,
      ),
      scaffoldBackgroundColor: AppColor.canvas,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      textTheme: AppType.textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColor.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColor.textSecondary, size: 20),
      cardTheme: const CardThemeData(
        color: AppColor.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.brand,
          foregroundColor: AppColor.textOnBrand,
          disabledBackgroundColor: AppColor.brand.withValues(alpha: 0.5),
          disabledForegroundColor: AppColor.textOnBrand,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColor.textPrimary,
          side: const BorderSide(color: AppColor.borderStrong),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColor.brand,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColor.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColor.textMuted, fontSize: 13),
        prefixIconColor: AppColor.textMuted,
        suffixIconColor: AppColor.textMuted,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColor.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColor.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColor.brand, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColor.danger),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColor.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColor.textPrimary,
          borderRadius: AppRadius.sm,
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColor.borderStrong.withValues(alpha: 0.9),
        ),
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }
}
