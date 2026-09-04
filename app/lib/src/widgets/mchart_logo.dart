import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_color.dart';
import '../theme/app_spacing.dart';

/// The MChart mark — a rounded white tile bordered in the design system's
/// subtle border color, containing the navy checkmark glyph.
class MChartLogo extends StatelessWidget {
  const MChartLogo({super.key, this.size = 34, this.bordered = true});

  final double size;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: bordered ? Border.all(color: AppColor.border) : null,
      ),
      child: SvgPicture.asset('assets/branding/mchart_mark.svg'),
    );
  }
}
