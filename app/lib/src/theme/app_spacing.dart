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

abstract final class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(6));
  static const md = BorderRadius.all(Radius.circular(8));
  static const lg = BorderRadius.all(Radius.circular(12));
  static const xl = BorderRadius.all(Radius.circular(16));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppShadow {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F101828), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const segment = <BoxShadow>[
    BoxShadow(color: Color(0x14101828), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

abstract final class AppLayout {
  static const sidebarWidth = 232.0;
  static const listPaneWidth = 300.0;
  static const topBarHeight = 60.0;
  static const contentMaxWidth = 1180.0;
  static const contentPadding = EdgeInsets.fromLTRB(28, 22, 28, 32);
}
