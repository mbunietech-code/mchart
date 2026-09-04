import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_color.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.label,
    this.size = 34,
    this.online,
    this.color,
    this.imageUrl,
  });

  AppAvatar.forUser(User user, {super.key, this.size = 34, bool? showPresence})
      : label = user.initials,
        online = showPresence == true ? user.isOnline : null,
        color = _colorFor(user.id),
        imageUrl = null;

  final String label;
  final double size;
  final bool? online;
  final Color? color;
  final String? imageUrl;

  static Color _colorFor(int seed) =>
      AppColor.departmentPalette[seed % AppColor.departmentPalette.length];

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? AppColor.brand).withValues(alpha: 0.14);
    final fg = color ?? AppColor.brand;

    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: imageUrl != null
          ? ClipOval(child: Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover))
          : Text(
              label,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );

    if (online == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: online! ? AppColor.online : AppColor.textMuted,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
