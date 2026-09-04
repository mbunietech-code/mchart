import 'package:flutter/material.dart';

import '../theme/app_color.dart';

/// The MChart mark: rounded blue square with a white "M" and a status dot.
class MChartLogo extends StatelessWidget {
  const MChartLogo({super.key, this.size = 34, this.showDot = true});

  final double size;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColor.brand, AppColor.navy],
              ),
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppColor.brand.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.56,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          if (showDot)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: AppColor.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
