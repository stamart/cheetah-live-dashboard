import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/dashboard/delta_bar.dart';
import '../widgets/dashboard/fuel_bar.dart';
import '../widgets/dashboard/lap_info_card.dart';
import '../widgets/dashboard/menu_exit_button.dart';
import '../widgets/dashboard/mini_status_bar.dart';
import '../widgets/dashboard/rpm_gauge.dart';
import '../widgets/dashboard/throttle_brake_chart.dart';
import '../widgets/dashboard/tire_panel.dart';

class DashboardPortraitLayout extends StatelessWidget {
  final bool ps5Online;
  final bool serverOnline;
  final VoidCallback? onDisconnect;

  final int currentLap;
  final int totalLaps;
  final int? positionCurrent;
  final int? positionTotal;
  final String lastLapTime;
  final String bestLapTime;

  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;
  final int gear;
  final double speedKmh;
  final double? fuelPct;
  final double? deltaSeconds;

  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;

  final double throttlePct;
  final double brakePct;

  const DashboardPortraitLayout({
    super.key,
    required this.ps5Online,
    required this.serverOnline,
    this.onDisconnect,
    required this.currentLap,
    required this.totalLaps,
    this.positionCurrent,
    this.positionTotal,
    required this.lastLapTime,
    required this.bestLapTime,
    required this.currentRpm,
    required this.maxRpm,
    required this.minAlertRpm,
    required this.maxAlertRpm,
    required this.gear,
    required this.speedKmh,
    this.fuelPct,
    this.deltaSeconds,
    required this.tireTempFL,
    required this.tireTempFR,
    required this.tireTempRL,
    required this.tireTempRR,
    required this.throttlePct,
    required this.brakePct,
  });

  @override
  Widget build(BuildContext context) {
    // No scrolling, ever: the whole stack is measured at its natural size against the
    // screen's actual width, then FittedBox shrinks (never grows) it to fit the available
    // height exactly. Gauge on top with POZYCJA/OKRĄŻENIE overlaid into its empty corners
    // (a circle inscribed in its own square bounding box always leaves the four corners
    // empty — free real estate, not stolen from anything else) is what makes this fit in
    // one screen at all; a separate lap/position row above the gauge, like landscape has
    // room for, doesn't fit here.
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MiniStatusBar(ps5Online: ps5Online, serverOnline: serverOnline, scale: 0.85),
                      const Spacer(),
                      if (onDisconnect != null) MenuExitButton(onPressed: onDisconnect!, scale: 0.85),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      Transform.scale(
                        scale: 1.2,
                        child: RpmGauge(
                          currentRpm: currentRpm,
                          maxRpm: maxRpm,
                          minAlertRpm: minAlertRpm,
                          maxAlertRpm: maxAlertRpm,
                          gear: gear,
                          speedKmh: speedKmh,
                          fuelPct: fuelPct,
                          showRpmValue: false,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        width: 110,
                        child: LapInfoCard.position(current: positionCurrent, total: positionTotal),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: 110,
                        child: LapInfoCard.lapCounter(current: currentLap, total: totalLaps),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(height: 48, child: DeltaBar(deltaSeconds: deltaSeconds)),
                  const SizedBox(height: 8),
                  SizedBox(height: 10, child: FuelBar(fuelPct: fuelPct)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lastLapTime,
                        style: const TextStyle(color: AppColors.textWhite, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        bestLapTime,
                        style: const TextStyle(color: AppColors.accentPurple, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TirePanel(tempFL: tireTempFL, tempFR: tireTempFR, tempRL: tireTempRL, tempRR: tireTempRR, rowGap: 10),
                  const SizedBox(height: 14),
                  ThrottleBrakeChart(throttlePct: throttlePct, brakePct: brakePct),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
