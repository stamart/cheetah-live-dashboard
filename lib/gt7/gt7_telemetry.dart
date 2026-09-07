/// One decoded GT7 telemetry sample — own car only. GT7's UDP packet carries no
/// data about other cars on track, so this can never be turned into a true
/// live position/leaderboard; the backend ranks by lap time instead.
class Gt7Telemetry {
  final double speedKph;
  final double rpm;
  final int currentLap;
  final int? lastLapTimeMs;
  final int? bestLapTimeMs;
  final double? fuelPct;
  final double throttlePct;
  final double brakePct;
  final bool inRace;
  final bool isPaused;

  const Gt7Telemetry({
    required this.speedKph,
    required this.rpm,
    required this.currentLap,
    required this.lastLapTimeMs,
    required this.bestLapTimeMs,
    required this.fuelPct,
    required this.throttlePct,
    required this.brakePct,
    required this.inRace,
    required this.isPaused,
  });
}
