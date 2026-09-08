import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Single bordered metric card — same widget backs the lap counter and both lap-time
/// cards, just with different parameters. Use the named constructors for the common cases.
class LapInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;
  final bool monospaceValue;

  const LapInfoCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor = AppColors.textWhite,
    this.monospaceValue = false,
  });

  /// "OKRĄŻENIE  8 / 22"
  const LapInfoCard.lapCounter({super.key, required int current, required int total})
      : label = 'OKRĄŻENIE',
        value = '$current',
        subValue = '/ $total',
        valueColor = AppColors.accentYellow,
        monospaceValue = false;

  /// "OSTATNIE OKRĄŻENIE  1:42.378" / "NAJLEPSZE OKRĄŻENIE  1:41.921"
  const LapInfoCard.lapTime({super.key, required this.label, required String time, this.valueColor = AppColors.textWhite})
      : value = time,
        subValue = null,
        monospaceValue = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          // FittedBox scales the value down if the card is too narrow for it at full size
          // (e.g. a 3-across portrait row with a long lap time) instead of overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFeatures: monospaceValue ? const [FontFeature.tabularFigures()] : null,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(width: 6),
                  Text(subValue!, style: const TextStyle(color: AppColors.textMuted, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
