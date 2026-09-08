import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/dashboard/app_logo.dart';
import '../widgets/dashboard/connection_status_row.dart';
import '../widgets/dashboard/footer_tagline.dart';
import '../widgets/dashboard/lap_info_card.dart';
import '../widgets/dashboard/live_clock.dart';
import '../widgets/dashboard/rpm_gauge.dart';
import '../widgets/dashboard/tire_panel.dart';

class DashboardPortraitLayout extends StatelessWidget {
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

  const DashboardPortraitLayout({
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppLogo(fontSize: 12),
                    const Spacer(),
                    LiveClock(fontSize: 9),
                    if (onDisconnect != null)
                      IconButton(
                        onPressed: onDisconnect,
                        icon: const Icon(Icons.meeting_room_outlined, color: AppColors.accentRed, size: 16),
                        tooltip: 'Rozłącz sesję',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.only(left: 6),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ConnectionStatusRow(
                  compact: true,
                  scale: 0.5,
                  driverName: driverName,
                  ps5Ip: ps5Ip,
                  ps5Online: ps5Online,
                  serverOnline: serverOnline,
                  wifiConnected: wifiConnected,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RpmGauge(
            currentRpm: currentRpm,
            maxRpm: maxRpm,
            minAlertRpm: minAlertRpm,
            maxAlertRpm: maxAlertRpm,
            gear: gear,
            speedKmh: speedKmh,
            fuelPct: fuelPct,
          ),
          const SizedBox(height: 16),
          TirePanel(tempFL: tireTempFL, tempFR: tireTempFR, tempRL: tireTempRL, tempRR: tireTempRR),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: LapInfoCard.lapCounter(current: currentLap, total: totalLaps)),
                const SizedBox(width: 10),
                Expanded(child: LapInfoCard.lapTime(label: 'OSTATNIE', time: lastLapTime)),
                const SizedBox(width: 10),
                Expanded(child: LapInfoCard.lapTime(label: 'NAJLEPSZE', time: bestLapTime, valueColor: AppColors.accentPurple)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const FooterTagline(),
        ],
      ),
    );
  }
}
