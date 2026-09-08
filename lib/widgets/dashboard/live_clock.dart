import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Self-ticking "HH:mm" clock, used both by ConnectionStatusRow's full variant and
/// directly in the portrait top bar (where the clock sits next to the logo instead).
class LiveClock extends StatefulWidget {
  final double fontSize;

  const LiveClock({super.key, this.fontSize = 16});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Text(
      '${two(_now.hour)}:${two(_now.minute)}',
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textWhite,
      ),
    );
  }
}
