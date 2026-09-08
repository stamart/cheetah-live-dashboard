import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "CHEETAH LIVE!" wordmark — leopard icon + "CHEETAH" (gold) + "LIVE" (white) + red "!".
/// `fontSize` drives every other dimension (icon size, spacing) so a single number scales
/// the whole lockup consistently between the landscape top bar (smaller) and the portrait
/// top bar (larger).
class AppLogo extends StatelessWidget {
  final double fontSize;

  const AppLogo({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    final iconSize = fontSize * 1.7;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/icon.png', width: iconSize, height: iconSize, fit: BoxFit.contain),
        SizedBox(width: fontSize * 0.35),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
              height: 1,
            ),
            children: [
              const TextSpan(text: 'CHEETAH ', style: TextStyle(color: AppColors.accentYellow)),
              const TextSpan(text: 'LIVE', style: TextStyle(color: AppColors.textWhite)),
              const TextSpan(text: '!', style: TextStyle(color: AppColors.accentRed)),
            ],
          ),
        ),
      ],
    );
  }
}
