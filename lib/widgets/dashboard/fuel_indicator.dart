import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Fuel pump icon + percentage. Pulses red when fuel drops below 10% — null (not yet
/// reported by GT7, e.g. before the first packet) shows a plain dash, no blinking.
class FuelIndicator extends StatefulWidget {
  final double? fuelPct;

  const FuelIndicator({super.key, required this.fuelPct});

  static const double lowFuelThreshold = 10;

  @override
  State<FuelIndicator> createState() => _FuelIndicatorState();
}

class _FuelIndicatorState extends State<FuelIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLow => (widget.fuelPct ?? 100) < FuelIndicator.lowFuelThreshold;

  @override
  Widget build(BuildContext context) {
    final pct = widget.fuelPct;
    final text = pct != null ? '${pct.round()}%' : '—';

    if (!_isLow) {
      return _FuelContent(color: AppColors.textWhite, opacity: 1, text: text);
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
          Icon(Icons.local_gas_station, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
