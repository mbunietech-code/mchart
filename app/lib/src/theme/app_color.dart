import 'package:flutter/material.dart';

/// MChart brand palette — locked to the approved MbuniTech brand tokens.
/// Do NOT invent new brand colors. Only the four brand tokens plus the minimal
/// functional status colors below are permitted.
///
///   Primary   #1E40AF  blue   — primary buttons, active nav, links, sent bubbles
///   Secondary #0F172A  navy   — headers, inverted buttons, dark surfaces
///   Accent    #F59E0B  amber  — priority/warning badges, unread counters, highlights
///   Neutral   #64748B  slate  — secondary text, borders, disabled states
abstract final class AppColor {
  // ----- Brand -------------------------------------------------------
  static const brand = Color(0xFF1E40AF);
  static const brandHover = Color(0xFF1B3A9E);
  static const brandActive = Color(0xFF17328A);
  static const brandSoft = Color(0xFFEAEEFB); // pale blue chip / active channel row
  static const brandSoftText = brand;

  static const navy = Color(0xFF0F172A);
  static const navySoft = Color(0xFFE8EBF0);

  static const accent = Color(0xFFF59E0B); // amber
  static const accentSoft = Color(0xFFFEF3E2);

  static const slate = Color(0xFF64748B);

  // ----- Surfaces --------------------------------------------------
  static const canvas = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9); // segmented track, table header, received bubble
  static const sidebar = Color(0xFFFFFFFF);
  static const overlayScrim = Color(0x330F172A);

  // ----- Lines -------------------------------------------------
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const track = Color(0xFFE8EDF3); // progress-bar track

  // ----- Text --------------------------------------------------
  static const textPrimary = navy;
  static const textSecondary = slate;
  static const textMuted = Color(0xFF94A3B8);
  static const textOnBrand = Color(0xFFFFFFFF);
  static const breadcrumb = slate;

  // ----- Functional status (minimal, not brand) --------------
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFE6F4EB);
  static const warning = accent;
  static const warningSoft = accentSoft;
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFCEBEB);
  static const info = brand;
  static const infoSoft = brandSoft;
  static const online = Color(0xFF22C55E);

  // ----- Priority (Low / Medium / High / Urgent) -------------
  static const priorityLow = slate;
  static const priorityMedium = brand;
  static const priorityHigh = accent;
  static const priorityUrgent = danger;

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
