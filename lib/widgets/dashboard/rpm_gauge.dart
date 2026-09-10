import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'fuel_indicator.dart';

/// Tachometer drawn as a fill/progress arc, not a needle: the unfilled part of the arc is
/// a dark track, and the filled part (0 -> currentRpm) is colored yellow up to 90% of
/// [maxRpm], red from 90-95%, and blinking red above 95% — a fixed proportion of max RPM,
/// not the car's own alert thresholds, so it reads the same way in every car.
/// No numeric labels on the scale — just tick marks — so it reads as a pure proportion of
/// max RPM at a glance from a distance, independent of the car's actual redline number.
class RpmGauge extends StatefulWidget {
  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;
  final int gear;
  final double speedKmh;
  final double? fuelPct;
  final bool showRpmValue;

  const RpmGauge({
    super.key,
    required this.currentRpm,
    required this.maxRpm,
    required this.minAlertRpm,
    required this.maxAlertRpm,
    required this.gear,
    required this.speedKmh,
    this.fuelPct,
    this.showRpmValue = true,
  });

  static const double redThreshold = 0.90;
  static const double blinkThreshold = 0.95;

  @override
  State<RpmGauge> createState() => _RpmGaugeState();
}

class _RpmGaugeState extends State<RpmGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _blinkController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RpmGaugePainter(
                        currentRpm: widget.currentRpm,
                        maxRpm: widget.maxRpm,
                        blinkOpacity: 0.3 + 0.7 * _blinkController.value,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: size * 0.7,
                    height: size * 0.7,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _GaugeReadout(
                        gear: widget.gear,
                        speedKmh: widget.speedKmh,
                        currentRpm: widget.currentRpm,
                        fuelPct: widget.fuelPct,
                        showRpmValue: widget.showRpmValue,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GaugeReadout extends StatelessWidget {
  final int gear;
  final double speedKmh;
  final double currentRpm;
  final double? fuelPct;
  final bool showRpmValue;

  const _GaugeReadout({
    required this.gear,
    required this.speedKmh,
    required this.currentRpm,
    this.fuelPct,
    this.showRpmValue = true,
  });

  /// 0 = neutral, 15 = reverse (standard GT convention) — otherwise the raw gear number.
  String get _gearLabel {
    if (gear == 0) return 'N';
    if (gear == 15) return 'R';
    return '$gear';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _gearLabel,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 128, fontWeight: FontWeight.w900, height: 0.9),
        ),
        const Text(
          'BIEG',
          style: TextStyle(color: AppColors.accentYellow, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              speedKmh.round().toString(),
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 72,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            const Text('km/h', style: TextStyle(color: AppColors.textMuted, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 18),
            FuelIndicator(fuelPct: fuelPct),
          ],
        ),
        if (showRpmValue) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentRpm.round().toString(),
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              const Text('RPM', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    );
  }
}

class _RpmGaugePainter extends CustomPainter {
  final double currentRpm;
  final double maxRpm;
  final double blinkOpacity;

  static const double _startAngleDeg = 150; // ~8 o'clock
  static const double _sweepAngleDeg = 240; // ends ~4 o'clock, open gap at the bottom

  _RpmGaugePainter({
    required this.currentRpm,
    required this.maxRpm,
    required this.blinkOpacity,
  });

  double _angleForRpm(double rpm) {
    final frac = (rpm / maxRpm).clamp(0.0, 1.0);
    return (_startAngleDeg + frac * _sweepAngleDeg) * math.pi / 180;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final arcRadius = radius * 0.88;
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
    const strokeWidth = 14.0;

    final startRad = _angleForRpm(0);
    final endRad = _angleForRpm(maxRpm);
    final redStartRad = _angleForRpm(maxRpm * RpmGauge.redThreshold);
    final blinkStartRad = _angleForRpm(maxRpm * RpmGauge.blinkThreshold);
    final currentRad = _angleForRpm(currentRpm);

    // Dark unfilled track across the whole scale first.
    canvas.drawArc(
      arcRect,
      startRad,
      endRad - startRad,
      false,
      Paint()
        ..color = AppColors.trackDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    // Filled part: 0 -> currentRpm. Yellow up to 90% of max RPM, solid red 90-95%,
    // blinking red above 95% — a fixed proportion of redline, same in every car.
    if (currentRad > startRad) {
      final yellowEndRad = math.min(currentRad, redStartRad);
      canvas.drawArc(
        arcRect,
        startRad,
        yellowEndRad - startRad,
        false,
        Paint()
          ..color = AppColors.accentYellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );

      if (currentRad > redStartRad) {
        final solidRedEndRad = math.min(currentRad, blinkStartRad);
        canvas.drawArc(
          arcRect,
          redStartRad,
          solidRedEndRad - redStartRad,
          false,
          Paint()
            ..color = AppColors.accentRed
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt,
        );

        if (currentRad > blinkStartRad) {
          canvas.drawArc(
            arcRect,
            blinkStartRad,
            currentRad - blinkStartRad,
            false,
            Paint()
              ..color = AppColors.accentRed.withValues(alpha: blinkOpacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.butt,
          );
        }
      }
    }

    _drawTicks(canvas, center, arcRadius, strokeWidth);
  }

  void _drawTicks(Canvas canvas, Offset center, double arcRadius, double bandWidth) {
    const tickCount = 40; // ticks only, no numeric labels — reads as a proportion, not a value
    for (var i = 0; i <= tickCount; i++) {
      final rpm = maxRpm * i / tickCount;
      final isMajor = i % 5 == 0;
      final angle = _angleForRpm(rpm);

      final tickLength = isMajor ? bandWidth * 0.9 : bandWidth * 0.4;
      final tickStrokeWidth = isMajor ? 2.2 : 1.2;

      final outerR = arcRadius + bandWidth / 2 + 2;
      final innerR = outerR - tickLength;
      final p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      final p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = AppColors.bgDark
          ..strokeWidth = tickStrokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RpmGaugePainter oldDelegate) {
    return oldDelegate.currentRpm != currentRpm ||
        oldDelegate.maxRpm != maxRpm ||
        oldDelegate.blinkOpacity != blinkOpacity;
  }
}
