import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Self-contained bordered card: a 2x2 grid of tire temperatures — left column is
/// FL/RL, right column is FR/RR, position alone conveys which corner (no FL/FR/RL/RR
/// labels needed). Used as-is in both orientations — only its parent's width differs.
class TirePanel extends StatelessWidget {
  final double tempFL;
  final double tempFR;
  final double tempRL;
  final double tempRR;

  /// Five-zone temperature bounds (°C): below [coldMaxTemp] is "cold" (blue), up to
  /// [greenMaxTemp] is in the good window (green), up to [yellowMaxTemp] is warm
  /// (yellow), up to [orangeMaxTemp] is hot (orange), above that is overheating (red).
  final double coldMaxTemp;
  final double greenMaxTemp;
  final double yellowMaxTemp;
  final double orangeMaxTemp;

  /// Vertical gap between the front and rear readout in each column — landscape has
  /// vertical room to spare; portrait passes a smaller value to flatten the card so it
  /// takes less of the screen's limited height.
  final double rowGap;

  const TirePanel({
    super.key,
    required this.tempFL,
    required this.tempFR,
    required this.tempRL,
    required this.tempRR,
    this.coldMaxTemp = 60,
    this.greenMaxTemp = 90,
    this.yellowMaxTemp = 100,
    this.orangeMaxTemp = 110,
    this.rowGap = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      // FittedBox scales the whole grid down if the parent is too narrow/short to fit it
      // at full size, instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TireReadout(tempC: tempFL, coldMaxTemp: coldMaxTemp, greenMaxTemp: greenMaxTemp, yellowMaxTemp: yellowMaxTemp, orangeMaxTemp: orangeMaxTemp),
                SizedBox(height: rowGap),
                _TireReadout(tempC: tempRL, coldMaxTemp: coldMaxTemp, greenMaxTemp: greenMaxTemp, yellowMaxTemp: yellowMaxTemp, orangeMaxTemp: orangeMaxTemp),
              ],
            ),
            const SizedBox(width: 28),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TireReadout(tempC: tempFR, coldMaxTemp: coldMaxTemp, greenMaxTemp: greenMaxTemp, yellowMaxTemp: yellowMaxTemp, orangeMaxTemp: orangeMaxTemp),
                SizedBox(height: rowGap),
                _TireReadout(tempC: tempRR, coldMaxTemp: coldMaxTemp, greenMaxTemp: greenMaxTemp, yellowMaxTemp: yellowMaxTemp, orangeMaxTemp: orangeMaxTemp),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TireReadout extends StatelessWidget {
  final double tempC;
  final double coldMaxTemp;
  final double greenMaxTemp;
  final double yellowMaxTemp;
  final double orangeMaxTemp;

  const _TireReadout({
    required this.tempC,
    required this.coldMaxTemp,
    required this.greenMaxTemp,
    required this.yellowMaxTemp,
    required this.orangeMaxTemp,
  });

  Color get _color {
    if (tempC < coldMaxTemp) return AppColors.accentBlue;
    if (tempC < greenMaxTemp) return AppColors.accentGreen;
    if (tempC < yellowMaxTemp) return AppColors.accentYellow;
    if (tempC < orangeMaxTemp) return AppColors.accentOrange;
    return AppColors.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${tempC.round()}°',
          style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(width: 8),
        Container(
          width: 9,
          height: 46,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }
}
