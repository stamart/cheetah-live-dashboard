import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Short, wide, purely graphical fuel gauge — no icon, no text, no percentage. Sits under
/// the RPM gauge and fills left-to-right in proportion to [fuelPct]. The whole fill is one
/// color reflecting the current level (not split into fixed thirds): green with plenty,
/// yellow under 30%, red under 15%, pulsing red under 5%.
class FuelBar extends StatefulWidget {
  final double? fuelPct;

  const FuelBar({super.key, required this.fuelPct});

  static const double warnThreshold = 30;
  static const double dangerThreshold = 15;
  static const double pulseThreshold = 5;

  @override
  State<FuelBar> createState() => _FuelBarState();
}

class _FuelBarState extends State<FuelBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isPulsing => (widget.fuelPct ?? 100) < FuelBar.pulseThreshold;

  Color get _fillColor {
    final pct = widget.fuelPct;
    if (pct == null) return AppColors.trackDark;
    if (pct < FuelBar.dangerThreshold) return AppColors.accentRed;
    if (pct < FuelBar.warnThreshold) return AppColors.accentYellow;
    return AppColors.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = ((widget.fuelPct ?? 0) / 100).clamp(0.0, 1.0);

    if (!_isPulsing) {
      return _Bar(fraction: fraction, color: _fillColor, opacity: 1);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + 0.65 * _controller.value;
        return _Bar(fraction: fraction, color: AppColors.accentRed, opacity: opacity);
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double opacity;

  const _Bar({required this.fraction, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: AppColors.fuelTrackDark,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: Opacity(opacity: opacity, child: Container(color: color)),
          ),
        ),
      ),
    );
  }
}
