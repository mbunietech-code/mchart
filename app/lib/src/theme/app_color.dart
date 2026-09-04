import 'package:flutter/material.dart';

/// MChart brand palette — sourced from the MbuniTech design system
/// (DESIGN.md). Do not invent new brand colors; extend semantic tokens here
/// only when the design system defines them.
abstract final class AppColor {
  // ----- Brand -------------------------------------------------------
  static const brand = Color(0xFF1E40AF);
  static const brandHover = Color(0xFF1D4ED8);
  static const brandActive = Color(0xFF1E3A8A);
  static const brandSoft = Color(0xFFEFF6FF); // brand-blue-subtle
  static const brandSoftText = brand;

  static const navy = Color(0xFF0F172A);
  static const navySoft = Color(0xFFE8EBF0);

  static const accent = Color(0xFFF59E0B); // amber — medium-priority / pending review
  static const accentSoft = Color(0xFFFEFCE8);

  static const slate = Color(0xFF64748B);

  // ----- Surfaces --------------------------------------------------
  static const canvas = Color(0xFFF8FAFC); // surface-page — app shell background
  static const surface = Color(0xFFFFFFFF); // surface-card
  static const surfaceMuted = Color(0xFFF1F5F9); // surface-subtle
  static const sidebar = Color(0xFFFFFFFF);
  static const overlayScrim = Color(0x660F172A); // 40% slate backdrop (Level 3)

  // ----- Lines -------------------------------------------------
  static const border = Color(0xFFE2E8F0); // border-subtle
  static const borderStrong = Color(0xFFCBD5E1); // border-strong
  static const track = Color(0xFFE8EDF3); // progress-bar track

  // ----- Text --------------------------------------------------
  static const textPrimary = navy;
  static const textSecondary = slate;
  static const textMuted = Color(0xFF94A3B8);
  static const textOnBrand = Color(0xFFFFFFFF);
  static const breadcrumb = slate;

  // ----- Semantic status (DESIGN.md "Semantic Workflows") -----
  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = accent;
  static const warningSoft = accentSoft;
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const urgent = Color(0xFFEA580C);
  static const urgentSoft = Color(0xFFFFF7ED);
  static const info = brand;
  static const infoSoft = brandSoft;
  static const online = success;

  // ----- Priority (Low / Medium / High / Urgent) -------------
  static const priorityLow = slate;
  static const priorityMedium = brand;
  static const priorityHigh = accent;
  static const priorityUrgent = urgent;

  // ----- Data-viz — brand-derived only ----------------------
  static const departmentPalette = <Color>[
    brand,
    accent,
    navy,
    slate,
    Color(0xFF3B60D0), // lighter brand tint
    Color(0xFFB45309), // deep amber tint
  ];
}
