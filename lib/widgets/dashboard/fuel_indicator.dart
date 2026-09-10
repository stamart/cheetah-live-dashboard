import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Fuel pump icon + percentage, shown inside the RPM gauge. Color signals urgency: white
/// when there's plenty, yellow under 40%, red under 20%, pulsing red under 5%. Null (not
/// yet reported by GT7, e.g. before the first packet) shows a plain dash, no color/pulse.
class FuelIndicator extends StatefulWidget {
  final double? fuelPct;

  const FuelIndicator({super.key, required this.fuelPct});

  // Same thresholds as FuelBar, so the icon+percentage and the bar always agree.
  static const double warnThreshold = 30;
  static const double dangerThreshold = 15;
  static const double pulseThreshold = 5;

  @override
  State<FuelIndicator> createState() => _FuelIndicatorState();
}

class _FuelIndicatorState extends State<FuelIndicator> with SingleTickerProviderStateMixin {
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

  bool get _isPulsing => (widget.fuelPct ?? 100) < FuelIndicator.pulseThreshold;

  Color get _color {
    final pct = widget.fuelPct;
    if (pct == null) return AppColors.textWhite;
    if (pct < FuelIndicator.dangerThreshold) return AppColors.accentRed;
    if (pct < FuelIndicator.warnThreshold) return AppColors.accentYellow;
    return AppColors.textWhite;
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.fuelPct;
    final text = pct != null ? '${pct.round()}%' : '—';

    if (!_isPulsing) {
      return _FuelContent(color: _color, opacity: 1, text: text);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + 0.65 * _controller.value;
        return _FuelContent(color: AppColors.accentRed, opacity: opacity, text: text);
      },
    );
  }
}

class _FuelContent extends StatelessWidget {
  final Color color;
  final double opacity;
  final String text;

  const _FuelContent({required this.color, required this.opacity, required this.text});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(Icons.local_gas_station, color: color, size: 28),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
