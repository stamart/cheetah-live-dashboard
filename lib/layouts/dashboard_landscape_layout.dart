import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/dashboard/lap_info_card.dart';
import '../widgets/dashboard/rpm_gauge.dart';
import '../widgets/dashboard/tire_panel.dart';

/// Landscape is the "racing" view — no top status bar (it barely fit and ate vertical
/// space landscape can't spare), just the gauge/tires/lap cards plus a small corner button
/// to disconnect. Pairs with HudScreen's auto-fullscreen (immersive system UI) in landscape.
class DashboardLandscapeLayout extends StatelessWidget {
  final String driverName;
  final String ps5Ip;
  final bool ps5Online;
  final bool serverOnline;
  final bool wifiConnected;
  final VoidCallback? onDisconnect;

  final int currentLap;
  final int totalLaps;
  final String lastLapTime;
  final String bestLapTime;

  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;
  final int gear;
  final double speedKmh;
  final double? fuelPct;

  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;

  const DashboardLandscapeLayout({
    super.key,
    required this.driverName,
    required this.ps5Ip,
    required this.ps5Online,
    required this.serverOnline,
    required this.wifiConnected,
    this.onDisconnect,
    required this.currentLap,
    required this.totalLaps,
    required this.lastLapTime,
    required this.bestLapTime,
    required this.currentRpm,
    required this.maxRpm,
    required this.minAlertRpm,
    required this.maxAlertRpm,
    required this.gear,
    required this.speedKmh,
    this.fuelPct,
    required this.tireTempFL,
    required this.tireTempFR,
    required this.tireTempRL,
    required this.tireTempRR,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      LapInfoCard.lapCounter(current: currentLap, total: totalLaps),
                      const SizedBox(height: 10),
                      LapInfoCard.lapTime(label: 'OSTATNIE OKRĄŻENIE', time: lastLapTime),
                      const SizedBox(height: 10),
                      LapInfoCard.lapTime(label: 'NAJLEPSZE OKRĄŻENIE', time: bestLapTime, valueColor: AppColors.accentPurple),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Center(
                  child: RpmGauge(
                    currentRpm: currentRpm,
                    maxRpm: maxRpm,
                    minAlertRpm: minAlertRpm,
                    maxAlertRpm: maxAlertRpm,
                    gear: gear,
                    speedKmh: speedKmh,
                    fuelPct: fuelPct,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TirePanel(tempFL: tireTempFL, tempFR: tireTempFR, tempRL: tireTempRL, tempRR: tireTempRR),
              ),
            ],
          ),
        ),
        if (onDisconnect != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: onDisconnect,
              icon: const Icon(Icons.meeting_room_outlined, color: AppColors.accentRed, size: 18),
              tooltip: 'Rozłącz sesję',
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}
