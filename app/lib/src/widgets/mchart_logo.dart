import 'package:flutter/material.dart';

/// The MChart mark — the navy rounded tile with the white chat bubble,
/// the same artwork as the launcher icon.
class MChartLogo extends StatelessWidget {
  const MChartLogo({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/mchart_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}
