import 'package:flutter/widgets.dart';

/// 4-pt spacing scale.
abstract final class Gap {
  static const xs = SizedBox(width: 4, height: 4);
  static const sm = SizedBox(width: 8, height: 8);
  static const md = SizedBox(width: 12, height: 12);
  static const lg = SizedBox(width: 16, height: 16);
  static const xl = SizedBox(width: 24, height: 24);
  static const xxl = SizedBox(width: 32, height: 32);

  static SizedBox w(double v) => SizedBox(width: v);
  static SizedBox h(double v) => SizedBox(height: v);
}

/// DESIGN.md "Shapes" — Soft(1) metric: 4px for buttons/inputs/badges,
/// 8px for cards/modals, 9999 reserved for pills.
abstract final class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(4));
  static const md = BorderRadius.all(Radius.circular(6));
  static const lg = BorderRadius.all(Radius.circular(8));
  static const xl = BorderRadius.all(Radius.circular(12));
  static const pill = BorderRadius.all(Radius.circular(999));
}

/// DESIGN.md "Elevation & Depth" — tonal layering + low-contrast outlines,
/// no heavy drop shadows.
abstract final class AppShadow {
  /// Level 1 — cards, message rows, dashboard widgets.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Level 2 — dropdowns, context menus.
  static const segment = <BoxShadow>[
    BoxShadow(color: Color(0x14101828), blurRadius: 6, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Level 3 — modals, drawers.
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 25, offset: Offset(0, 20)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 8)),
  ];
}

abstract final class AppLayout {
  static const sidebarWidth = 232.0;
  static const listPaneWidth = 300.0;
  static const topBarHeight = 60.0;
  static const contentMaxWidth = 1180.0;
  static const contentPadding = EdgeInsets.fromLTRB(28, 22, 28, 32);
}
