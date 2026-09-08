import 'package:flutter/material.dart';

import '../layouts/dashboard_landscape_layout.dart';
import '../layouts/dashboard_portrait_layout.dart';
import '../theme/app_colors.dart';

/// Static preview of the redesigned dashboard — all data below is mocked (matches the
/// reference screenshots). Not wired to GT7 telemetry or the pairing flow yet; that comes
/// once the layout itself is signed off.
class DashboardScreen extends StatelessWidget {
  // -- Connection --
  final String driverName;
  final String ps5Ip;
  final bool ps5Online;
  final bool serverOnline;
  final bool wifiConnected;
  final VoidCallback? onDisconnect;

  // -- Lap info --
  final int currentLap;
  final int totalLaps;
  final String lastLapTime;
  final String bestLapTime;

  // -- RPM gauge (minAlertRpm/maxAlertRpm are per-car — GT7 sends these) --
  final double currentRpm;
  final double maxRpm;
  final double minAlertRpm;
  final double maxAlertRpm;
  final int gear;
  final double speedKmh;
  final double? fuelPct;

  // -- Tires --
  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;

  const DashboardScreen({
    super.key,
    this.driverName = 'CheetahDriver',
    this.ps5Ip = '192.168.1.42',
    this.ps5Online = true,
    this.serverOnline = true,
    this.wifiConnected = true,
    this.onDisconnect,
    this.currentLap = 8,
    this.totalLaps = 22,
    this.lastLapTime = '1:42.378',
    this.bestLapTime = '1:41.921',
    this.currentRpm = 7820,
    this.maxRpm = 10000,
    this.minAlertRpm = 7000,
    this.maxAlertRpm = 8500,
    this.gear = 4,
    this.speedKmh = 198,
    this.fuelPct = 64,
    this.tireTempFL = 84,
    this.tireTempFR = 87,
    this.tireTempRL = 82,
    this.tireTempRR = 85,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.landscape
                ? DashboardLandscapeLayout(
                    driverName: driverName,
                    ps5Ip: ps5Ip,
                    ps5Online: ps5Online,
                    serverOnline: serverOnline,
                    wifiConnected: wifiConnected,
                    onDisconnect: onDisconnect,
                    currentLap: currentLap,
                    totalLaps: totalLaps,
                    lastLapTime: lastLapTime,
                    bestLapTime: bestLapTime,
                    currentRpm: currentRpm,
                    maxRpm: maxRpm,
                    minAlertRpm: minAlertRpm,
                    maxAlertRpm: maxAlertRpm,
                    gear: gear,
                    speedKmh: speedKmh,
                    fuelPct: fuelPct,
                    tireTempFL: tireTempFL,
                    tireTempFR: tireTempFR,
                    tireTempRL: tireTempRL,
                    tireTempRR: tireTempRR,
                  )
                : DashboardPortraitLayout(
                    driverName: driverName,
                    ps5Ip: ps5Ip,
                    ps5Online: ps5Online,
                    serverOnline: serverOnline,
                    wifiConnected: wifiConnected,
                    onDisconnect: onDisconnect,
                    currentLap: currentLap,
                    totalLaps: totalLaps,
                    lastLapTime: lastLapTime,
                    bestLapTime: bestLapTime,
                    currentRpm: currentRpm,
                    maxRpm: maxRpm,
                    minAlertRpm: minAlertRpm,
                    maxAlertRpm: maxAlertRpm,
                    gear: gear,
                    speedKmh: speedKmh,
                    fuelPct: fuelPct,
                    tireTempFL: tireTempFL,
                    tireTempFR: tireTempFR,
                    tireTempRL: tireTempRL,
                    tireTempRR: tireTempRR,
                  );
          },
        ),
      ),
    );
  }
}
