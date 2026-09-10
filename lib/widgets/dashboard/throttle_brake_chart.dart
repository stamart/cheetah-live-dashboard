import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "GAZ / HAMULEC" card: a 5-second scrolling history line chart (throttle green, brake
/// red, both 0-100%) plus two live vertical bars with the current values underneath.
///
/// The widget owns its own rolling history buffer — every rebuild with new
/// [throttlePct]/[brakePct] values is treated as one telemetry sample, timestamped with
/// [DateTime.now()], and samples older than 5s are pruned. That means the chart's time
/// resolution follows however often the parent rebuilds (the live GT7 telemetry stream),
/// not a separate timer of its own.
class ThrottleBrakeChart extends StatefulWidget {
  final double throttlePct;
  final double brakePct;

  const ThrottleBrakeChart({super.key, required this.throttlePct, required this.brakePct});

  static const Duration window = Duration(seconds: 5);

  @override
  State<ThrottleBrakeChart> createState() => _ThrottleBrakeChartState();
}

class _Sample {
  final DateTime time;
  final double throttle;
  final double brake;
  const _Sample(this.time, this.throttle, this.brake);
}

class _ThrottleBrakeChartState extends State<ThrottleBrakeChart> {
  final List<_Sample> _history = [];

  @override
  void initState() {
    super.initState();
    _pushSample();
  }

  @override
  void didUpdateWidget(covariant ThrottleBrakeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sample on every rebuild, not just when the value changes — a held-flat throttle
    // (0% coasting, or 100% pinned) is a real, common signal, and skipping it meant the
    // history stopped growing while old points kept aging out, so the whole trace would
    // scroll off the left edge and vanish even though telemetry was still flowing.
    _pushSample();
  }

  void _pushSample() {
    final now = DateTime.now();
    _history.add(_Sample(now, widget.throttlePct, widget.brakePct));
    final cutoff = now.subtract(ThrottleBrakeChart.window);
    _history.removeWhere((s) => s.time.isBefore(cutoff));
  }

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
          // No header label — a green/red throttle-brake trace is self-explanatory.
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _ChartPainter(history: List.of(_history)),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(width: 12),
                _LiveBar(pct: widget.throttlePct, color: AppColors.accentGreen),
                const SizedBox(width: 8),
                _LiveBar(pct: widget.brakePct, color: AppColors.accentRed),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBar extends StatelessWidget {
  final double pct;
  final Color color;

  const _LiveBar({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = (pct / 100).clamp(0.0, 1.0);
    // No percentage label — a driver glancing at this mid-corner reads bar height, not
    // digits, so the bar itself is sized as large as the card allows instead.
    return SizedBox(
      width: 30,
      height: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Container(
          color: AppColors.trackDark,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(heightFactor: fraction, child: Container(color: color)),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Sample> history;

  _ChartPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid.
    final gridPaint = Paint()
      ..color = const Color(0xFF202327)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (history.length < 2) return;

    final now = DateTime.now();
    final windowMs = ThrottleBrakeChart.window.inMilliseconds.toDouble();

    Offset pointFor(_Sample s, double value) {
      final ageMs = now.difference(s.time).inMilliseconds.toDouble();
      final x = size.width * (1 - (ageMs / windowMs).clamp(0.0, 1.0));
      final y = size.height * (1 - (value / 100).clamp(0.0, 1.0));
      return Offset(x, y);
    }

    void drawLine(double Function(_Sample) valueOf, Color color) {
      final path = Path();
      for (var i = 0; i < history.length; i++) {
        final p = pointFor(history[i], valueOf(history[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    drawLine((s) => s.brake, AppColors.accentRed);
    drawLine((s) => s.throttle, AppColors.accentGreen);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
