/// One decoded GT7 telemetry sample — own car only. GT7's UDP packet carries no
/// data about other cars on track, so this can never be turned into a true
/// live position/leaderboard; the backend ranks by lap time instead.
class Gt7Telemetry {
  final double speedKph;
  final double rpm;
  /// Raw gear nibble from the packet: 0 = neutral, 1-8 = forward gears, 15 = reverse
  /// (standard GT convention — not yet cross-checked against a real reverse-gear capture).
  final int gear;
  /// Rev-limiter alert thresholds GT7 reports for the current car — these are what the
  /// RPM gauge's colored zones scale against, not a fixed 0-6-8-10 layout.
  final double minAlertRpm;
  final double maxAlertRpm;
  final int currentLap;
  final int totalLaps;
  final int? lastLapTimeMs;
  final int? bestLapTimeMs;
  final double? fuelPct;
  final double throttlePct;
  final double brakePct;
  final bool inRace;
  final bool isPaused;
  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;
  // Raw world-space position (own car only). No rotation/scale calibration from GT7 —
  // only useful for plotting a track's shape from the accumulated path, not as
  // real-world coordinates. Y is vertical height, not used for a top-down map.
  final double positionX;
  final double positionY;
  final double positionZ;

  const Gt7Telemetry({
    required this.speedKph,
    required this.rpm,
    required this.gear,
    required this.minAlertRpm,
    required this.maxAlertRpm,
    required this.currentLap,
    required this.totalLaps,
    required this.lastLapTimeMs,
    required this.bestLapTimeMs,
    required this.fuelPct,
    required this.throttlePct,
    required this.brakePct,
    required this.inRace,
    required this.isPaused,
    required this.tireTempFL,
    required this.tireTempFR,
    required this.tireTempRL,
    required this.tireTempRR,
    required this.positionX,
    required this.positionY,
    required this.positionZ,
  });
}
