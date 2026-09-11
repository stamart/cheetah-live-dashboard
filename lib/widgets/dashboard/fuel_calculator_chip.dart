import 'package:flutter/material.dart';

import '../../gt7/fuel_calculator.dart';
import '../../theme/app_colors.dart';

/// Persistent, always-visible entry point for the race fuel calculator. Before a race
/// config is set it just invites the driver to tap it; once set, the same chip shows the
/// live result. Tapping it always reopens the config sheet (so a driver can correct a
/// mis-set format/duration mid-session), it's never a one-shot thing.
class FuelCalculatorChip extends StatelessWidget {
  final RaceConfig? config;
  final FuelCalculatorResult? result;
  final VoidCallback onTap;
  final double scale;

  const FuelCalculatorChip({
    super.key,
    required this.config,
    required this.result,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final String text;
    final Color color;
    if (config == null) {
      text = '⛽ Ustaw sesję';
      color = AppColors.textMuted;
    } else if (r == null) {
      text = '⛽ Licz zużycie…';
      color = AppColors.textMuted;
    } else if (r.fuelDeficitPct > 0) {
      text = '⛽ +${r.fuelDeficitPct.round()}% potrzebne';
      color = AppColors.accentRed;
    } else {
      text = '⛽ OK (${r.remainingLaps} okr.)';
      color = AppColors.accentGreen;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13 * scale, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
