import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "DRIVE • ANALYZE • IMPROVE" — portrait-only footer, for now.
class FooterTagline extends StatelessWidget {
  const FooterTagline({super.key});

  @override
  Widget build(BuildContext context) {
    const wordStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 13,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      letterSpacing: 3,
    );
    const dotStyle = TextStyle(color: AppColors.accentYellow, fontSize: 13, fontWeight: FontWeight.w700);

    return const Center(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'DRIVE', style: wordStyle),
          TextSpan(text: '  •  ', style: dotStyle),
          TextSpan(text: 'ANALYZE', style: wordStyle),
          TextSpan(text: '  •  ', style: dotStyle),
          TextSpan(text: 'IMPROVE', style: wordStyle),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }
}
