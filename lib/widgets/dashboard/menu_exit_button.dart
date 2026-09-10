import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "↪ MENU" button — exits the live dashboard back to Cheetah Live's own setup/menu
/// screen (it does not close the app). Gray/white by default, a big invisible tap target
/// (48x48 min) even though the icon+label themselves are smaller, since this sits in a
/// corner drivers tap mid-drive without looking closely.
class MenuExitButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double scale;

  const MenuExitButton({super.key, required this.onPressed, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minWidth: 48 * scale, minHeight: 48 * scale),
          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.exit_to_app, color: AppColors.textMuted, size: 20 * scale),
              SizedBox(width: 6 * scale),
              Text(
                'MENU',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14 * scale, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
