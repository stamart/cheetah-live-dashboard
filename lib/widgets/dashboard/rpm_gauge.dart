import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'fuel_indicator.dart';

/// Tachometer with alert zones that scale to the current car — nothing is hardcoded to a
/// 0-6-8-10 layout. Zone boundaries (and the numeric ticks) are always computed as a
/// fraction of [maxRpm], so a 7000rpm-limiter car and a 9000rpm-limiter car both draw
/// correctly, and the gauge redraws itself if the car (and therefore [minAlertRpm] /
/// [maxAlertRpm]) changes mid-session.
///
/// Convention: RPM values are raw (e.g. 7820), but the arc's numeric ticks are labelled in
/// thousands (0..maxRpm/1000) like a real tachometer — matches the reference design.
class RpmGauge extends StatelessWidget {
  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;
  final int gear;
  final double speedKmh;
  final double? fuelPct;

  const RpmGauge({
    super.key,
    required this.currentRpm,
    required this.maxRpm,
    required this.minAlertRpm,
    required this.maxAlertRpm,
    required this.gear,
    required this.speedKmh,
    this.fuelPct,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RpmGaugePainter(
                    currentRpm: currentRpm,
                    maxRpm: maxRpm,
                    minAlertRpm: minAlertRpm,
                    maxAlertRpm: maxAlertRpm,
                  ),
                ),
              ),
              SizedBox(
                width: size * 0.64,
                height: size * 0.64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _GaugeReadout(gear: gear, speedKmh: speedKmh, currentRpm: currentRpm, fuelPct: fuelPct),
                ),
              ),
            ],
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

  const _GaugeReadout({required this.gear, required this.speedKmh, required this.currentRpm, this.fuelPct});

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
          ],
        ),
        const SizedBox(height: 4),
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
            const SizedBox(width: 18),
            FuelIndicator(fuelPct: fuelPct),
          ],
        ),
      ],
    );
  }
}

class _RpmGaugePainter extends CustomPainter {
  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;

  static const double _startAngleDeg = 150; // ~8 o'clock
  static const double _sweepAngleDeg = 240; // ends ~4 o'clock, open gap at the bottom

  _RpmGaugePainter({
    required this.currentRpm,
    required this.maxRpm,
    required this.minAlertRpm,
    required this.maxAlertRpm,
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
    final minAlertRad = _angleForRpm(minAlertRpm);
    final maxAlertRad = _angleForRpm(maxAlertRpm);
    final endRad = _angleForRpm(maxRpm);

    // Yellow zone: 0 -> minAlertRpm.
    canvas.drawArc(
      arcRect,
      startRad,
      minAlertRad - startRad,
      false,
      Paint()
        ..color = AppColors.accentYellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    // Orange zone: minAlertRpm -> maxAlertRpm, gradient smoothly out of yellow.
    canvas.drawArc(
      arcRect,
      minAlertRad,
      maxAlertRad - minAlertRad,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: minAlertRad,
          endAngle: maxAlertRad,
          colors: const [AppColors.accentYellow, AppColors.accentOrange],
        ).createShader(arcRect),
    );

    // Red zone: maxAlertRpm -> maxRpm (redline).
    canvas.drawArc(
      arcRect,
      maxAlertRad,
      endRad - maxAlertRad,
      false,
      Paint()
        ..color = AppColors.accentRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    _drawTicksAndLabels(canvas, center, arcRadius, strokeWidth, maxAlertRad);
    _drawNeedleValue(canvas, center, arcRadius);
  }

  void _drawTicksAndLabels(Canvas canvas, Offset center, double arcRadius, double bandWidth, double maxAlertRad) {
    final majorStep = maxRpm / 10; // 11 major ticks: 0..10 (or 0..maxRpm/1000 if not a multiple of 10k)
    final minorStep = majorStep / 5;

    for (double rpm = 0; rpm <= maxRpm + 0.01; rpm += minorStep) {
      final isMajor = (rpm / majorStep) % 1 < 0.001 || (rpm / majorStep) % 1 > 0.999;
      final angle = _angleForRpm(rpm);
      final isRedline = rpm >= maxAlertRpm - 0.01;

      final tickLength = isMajor ? bandWidth * 0.9 : bandWidth * 0.45;
      final tickStrokeWidth = isMajor ? (isRedline ? 3.0 : 2.2) : (isRedline ? 2.2 : 1.4);

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

      if (isMajor) {
        final labelR = outerR + 20;
        final labelPos = Offset(center.dx + labelR * math.cos(angle), center.dy + labelR * math.sin(angle));
        final label = (rpm / majorStep).round().toString();
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _drawNeedleValue(Canvas canvas, Offset center, double arcRadius) {
    // A short bright indicator tick at the current RPM position, on the inner edge of the band.
    final angle = _angleForRpm(currentRpm);
    final outerR = arcRadius + 10;
    final innerR = arcRadius - 14;
    final p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
    final p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = AppColors.textWhite
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RpmGaugePainter oldDelegate) {
    return oldDelegate.currentRpm != currentRpm ||
        oldDelegate.maxRpm != maxRpm ||
        oldDelegate.minAlertRpm != minAlertRpm ||
        oldDelegate.maxAlertRpm != maxAlertRpm;
  }
}
