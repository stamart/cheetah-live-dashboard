import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Self-contained bordered card: "OPONY (°C)" header + a row of FL/FR/[car]/RL/RR tire
/// temperature readouts. Used as-is in both orientations — only its parent's width differs.
class TirePanel extends StatelessWidget {
  final double tempFL;
  final double tempFR;
  final double tempRL;
  final double tempRR;

  /// Temperatures at/below this are shown in green ("in range"); above it, amber.
  final double normalMaxTemp;

  const TirePanel({
    super.key,
    required this.tempFL,
    required this.tempFR,
    required this.tempRL,
    required this.tempRR,
    this.normalMaxTemp = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'OPONY (°C)',
            style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          // FittedBox scales the whole row down if the parent is too narrow to fit all five
          // fixed-size items at full size, instead of overflowing (landscape's side columns
          // can be tight) — every child below must have an intrinsic size for this to work,
          // so the car icon uses a fixed-size SizedBox rather than Expanded.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TireReadout(label: 'FL', tempC: tempFL, normalMaxTemp: normalMaxTemp),
                const SizedBox(width: 14),
                _TireReadout(label: 'FR', tempC: tempFR, normalMaxTemp: normalMaxTemp),
                const SizedBox(width: 8),
                const SizedBox(width: 48, child: Center(child: _CarTopIcon())),
                const SizedBox(width: 8),
                _TireReadout(label: 'RL', tempC: tempRL, normalMaxTemp: normalMaxTemp),
                const SizedBox(width: 14),
                _TireReadout(label: 'RR', tempC: tempRR, normalMaxTemp: normalMaxTemp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TireReadout extends StatelessWidget {
  final String label;
  final double tempC;
  final double normalMaxTemp;

  const _TireReadout({required this.label, required this.tempC, required this.normalMaxTemp});

  @override
  Widget build(BuildContext context) {
    final inRange = tempC <= normalMaxTemp;
    final color = inRange ? AppColors.accentGreen : AppColors.accentOrange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${tempC.round()}°',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 5),
            Container(
              width: 6,
              height: 26,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Minimalist top-down car silhouette, drawn rather than relying on an icon asset.
class _CarTopIcon extends StatelessWidget {
  const _CarTopIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 64,
      child: CustomPaint(painter: _CarTopIconPainter()),
    );
  }
}

class _CarTopIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.04, size.width * 0.76, size.height * 0.92),
      Radius.circular(size.width * 0.32),
    );
    canvas.drawRRect(body, paint);

    final windshield = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, size.height * 0.28, size.width * 0.56, size.height * 0.32),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(windshield, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
