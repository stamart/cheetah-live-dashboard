import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Delta-vs-best-lap bar with a centered +/- time readout. Fills outward from a center
/// divider: red to the left when behind the best lap's pace at this point on track, green
/// to the right when ahead. Magnitude is clamped at [maxDeltaSeconds] (full half-width)
/// since a delta bigger than that isn't usefully more informative at a glance. Null (no
/// best-lap reference yet, e.g. first lap of the session) renders as a flat, empty track
/// with a dash instead of a time.
class DeltaBar extends StatelessWidget {
  final double? deltaSeconds;
  final double maxDeltaSeconds;

  const DeltaBar({super.key, required this.deltaSeconds, this.maxDeltaSeconds = 1.5});

  String get _label {
    final d = deltaSeconds;
    if (d == null) return '—';
    final sign = d > 0 ? '+' : (d < 0 ? '-' : '');
    return '$sign${d.abs().toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final delta = deltaSeconds;
    final fraction = delta == null ? 0.0 : (delta.abs() / maxDeltaSeconds).clamp(0.0, 1.0);
    final ahead = (delta ?? 0) < 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: AppColors.fuelTrackDark,
            child: Row(
              children: [
                // Left = red (behind pace).
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: ahead ? 0 : fraction,
                      heightFactor: 1,
                      child: Container(color: AppColors.accentRed),
                    ),
                  ),
                ),
                Container(width: 2, color: AppColors.borderGray),
                // Right = green (ahead of pace).
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ahead ? fraction : 0,
                      heightFactor: 1,
                      child: Container(color: AppColors.accentGreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _label,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
