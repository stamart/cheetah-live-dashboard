import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Small "mm:ss" countdown to the end of a time-based race. Only ever shown when the
/// active race config is time-based — lap-based races use the existing lap counter card
/// instead, there's no separate clock for those.
class RaceCountdown extends StatelessWidget {
  final double remainingSeconds;
  final double scale;

  const RaceCountdown({super.key, required this.remainingSeconds, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final s = remainingSeconds.clamp(0, double.infinity).toInt();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return Text(
      '⏱ $mm:$ss',
      style: TextStyle(
        color: AppColors.textWhite,
        fontSize: 15 * scale,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
