import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Single bordered metric card — same widget backs the lap counter, position, and both
/// lap-time cards, just with different parameters. Use the named constructors for the
/// common cases.
class LapInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;
  final bool monospaceValue;
  final bool showLabel;
  final bool labelBelow;
  final double valueFontSize;

  const LapInfoCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor = AppColors.textWhite,
    this.monospaceValue = false,
    this.showLabel = true,
    this.labelBelow = false,
    this.valueFontSize = 28,
  });

  /// Just the lap number — no caption, position in the grid already says what it is.
  const LapInfoCard.lapCounter({super.key, required int current, required int total})
      : label = '',
        value = '$current',
        subValue = '/ $total',
        valueColor = AppColors.accentYellow,
        monospaceValue = false,
        showLabel = false,
        labelBelow = false,
        valueFontSize = 33.6;

  /// No caption — an ordinal ("1st", "4th") already reads as a position, and the rank
  /// colors (gold/bronze/silver, per spec) reinforce it further. Null current (position
  /// isn't derivable from the GT7 packet itself, only from backend-side ranking across
  /// joined sessions) shows a plain dash.
  factory LapInfoCard.position({Key? key, required int? current, required int? total}) {
    return LapInfoCard(
      key: key,
      label: '',
      value: current != null ? _ordinal(current) : '—',
      subValue: null,
      valueColor: _rankColor(current),
      showLabel: false,
      valueFontSize: _kOrdinalFontSize,
    );
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  static Color _rankColor(int? position) {
    switch (position) {
      case 1:
        return AppColors.rankGold;
      case 2:
        return AppColors.rankBronze;
      case 3:
        return AppColors.rankSilver;
      default:
        return AppColors.textWhite;
    }
  }

  /// "LAST  1:42.378" / "BEST  1:41.921"
  const LapInfoCard.lapTime({super.key, required this.label, required String time, this.valueColor = AppColors.textWhite})
      : value = time,
        subValue = null,
        monospaceValue = true,
        showLabel = true,
        labelBelow = false,
        valueFontSize = 33.6;

  static const double _kOrdinalFontSize = 57.6;

  @override
  Widget build(BuildContext context) {
    final valueRow = FittedBox(
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
              fontSize: valueFontSize,
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
    );

    final labelText = Text(
      label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: showLabel && !labelBelow
            ? [labelText, const SizedBox(height: 6), valueRow]
            : showLabel && labelBelow
                ? [valueRow, const SizedBox(height: 4), labelText]
                : [valueRow],
      ),
    );
  }
}

/// LAST + BEST lap time in one card, label inline to the left of the value instead of
/// above it — one border/padding instead of two separate cards, and the saved vertical
/// space goes to a bigger time font instead.
class LapTimesCard extends StatelessWidget {
  final String lastTime;
  final String bestTime;

  const LapTimesCard({super.key, required this.lastTime, required this.bestTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeRow(time: lastTime, color: AppColors.textWhite),
          const SizedBox(height: 10),
          _TimeRow(time: bestTime, color: AppColors.accentPurple),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String time;
  final Color color;

  const _TimeRow({required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        time,
        style: TextStyle(color: color, fontSize: 40.8, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
