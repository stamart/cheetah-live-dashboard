import 'package:flutter/material.dart';

import '../gt7/fuel_calculator.dart';
import '../widgets/dashboard/delta_bar.dart';
import '../widgets/dashboard/fuel_bar.dart';
import '../widgets/dashboard/fuel_calculator_chip.dart';
import '../widgets/dashboard/lap_info_card.dart';
import '../widgets/dashboard/menu_exit_button.dart';
import '../widgets/dashboard/mini_status_bar.dart';
import '../widgets/dashboard/race_countdown.dart';
import '../widgets/dashboard/rpm_gauge.dart';
import '../widgets/dashboard/throttle_brake_chart.dart';
import '../widgets/dashboard/tire_panel.dart';

/// Landscape is the "racing" view: three zones (~25% left telemetry / ~48% central
/// cockpit / ~27% right telemetry) with generous black space between modules — this is
/// meant to be glanceable at a distance while driving, not maximally dense. Pairs with
/// HudScreen's auto-fullscreen (immersive system UI) in landscape.
class DashboardLandscapeLayout extends StatelessWidget {
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
  final RaceConfig? raceConfig;
  final FuelCalculatorResult? fuelResult;
  final double? remainingRaceSeconds;
  final VoidCallback? onFuelChipTap;
  final int? lapsOnCurrentFuel;

  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;

  final double throttlePct;
  final double brakePct;

  const DashboardLandscapeLayout({
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
    this.raceConfig,
    this.fuelResult,
    this.remainingRaceSeconds,
    this.onFuelChipTap,
    this.lapsOnCurrentFuel,
    required this.tireTempFL,
    required this.tireTempFR,
    required this.tireTempRL,
    required this.tireTempRR,
    required this.throttlePct,
    required this.brakePct,
  });

  @override
  Widget build(BuildContext context) {
    // The status bar and MENU button float over the content as a Stack overlay rather than
    // sitting in the Column's normal flow — landscape screens are short (this is a phone
    // rotated on its side, not a tablet), so every dp of in-flow header height is dp taken
    // straight out of the RPM gauge's available space. An overlay costs nothing.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 40, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 25,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: LapInfoCard.lapCounter(current: currentLap, total: totalLaps)),
                          const SizedBox(width: 10),
                          Expanded(child: LapInfoCard.position(current: positionCurrent, total: positionTotal)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LapTimesCard(lastTime: lastLapTime, bestTime: bestLapTime),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Transform.scale(
                        scale: 1.2,
                        child: RpmGauge(
                          currentRpm: currentRpm,
                          maxRpm: maxRpm,
                          minAlertRpm: minAlertRpm,
                          maxAlertRpm: maxAlertRpm,
                          gear: gear,
                          speedKmh: speedKmh,
                          fuelPct: fuelPct,
                          fuelResult: fuelResult,
                          lapsOnCurrentFuel: lapsOnCurrentFuel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 48, width: 320, child: DeltaBar(deltaSeconds: deltaSeconds)),
                    const SizedBox(height: 6),
                    SizedBox(height: 11, width: 320, child: FuelBar(fuelPct: fuelPct)),
                    const SizedBox(height: 10),
                    if (onFuelChipTap != null)
                      FuelCalculatorChip(config: raceConfig, result: fuelResult, onTap: onFuelChipTap!),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 27,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TirePanel(tempFL: tireTempFL, tempFR: tireTempFR, tempRL: tireTempRL, tempRR: tireTempRR),
                      const SizedBox(height: 10),
                      ThrottleBrakeChart(throttlePct: throttlePct, brakePct: brakePct),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          child: MiniStatusBar(ps5Online: ps5Online, serverOnline: serverOnline, scale: 0.85),
        ),
        if (remainingRaceSeconds != null)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(child: RaceCountdown(remainingSeconds: remainingRaceSeconds!)),
          ),
        if (onDisconnect != null)
          Positioned(
            top: 0,
            right: 4,
            child: MenuExitButton(onPressed: onDisconnect!, scale: 0.75),
          ),
      ],
    );
  }
}
