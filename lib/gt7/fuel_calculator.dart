import 'dart:math' as math;

/// What kind of session the driver is doing. Only meaningful for the fuel calculator when
/// it's [race] — training/qualifying never need a "fuel to finish" number.
enum RaceSessionType { training, qualifying, race }

/// How a race's length is defined — GT7 telemetry has no field for either the format or
/// its value; both come from event config (once the backend sends it) or, in an ad-hoc
/// session, the driver's own manual entry.
enum RaceFormat { time, laps }

class RaceConfig {
  final RaceSessionType sessionType;
  final RaceFormat? format;
  final double? durationMinutes;
  final int? totalLaps;

  const RaceConfig({
    required this.sessionType,
    this.format,
    this.durationMinutes,
    this.totalLaps,
  });

  bool get isTimedRace => sessionType == RaceSessionType.race && format == RaceFormat.time && durationMinutes != null;
  bool get isLapRace => sessionType == RaceSessionType.race && format == RaceFormat.laps && totalLaps != null;
}

class FuelCalculatorResult {
  final int remainingLaps;
  final double fuelNeededPct;
  final double fuelDeficitPct; // > 0 = short by this much (% of tank), <= 0 = enough fuel
  const FuelCalculatorResult({
    required this.remainingLaps,
    required this.fuelNeededPct,
    required this.fuelDeficitPct,
  });
}

/// Tracks fuel-per-lap and total race elapsed time, and — once a [config] is set —
/// computes how much fuel is needed to reach the end of the race. Doesn't need track
/// position data at all: only wall-clock time, lap boundaries (same detection approach as
/// [LapDeltaTracker]), and fuel level.
///
/// The race clock is deliberately separate from the per-lap timer: it starts once (the
/// first sample this tracker ever sees) and never resets at a lap boundary, unlike the
/// per-lap elapsed time which resets every lap.
class FuelCalculator {
  static const int _rollingWindow = 3;
  static const double _safetyMarginLaps = 0.5;

  RaceConfig? config;

  int? _lastSeenLap;
  double? _fuelAtLapStart;
  final List<double> _fuelPerLapHistory = [];
  final List<double> _lapTimeHistory = [];
  double _elapsedInLap = 0;

  double _elapsedRaceTime = 0;
  DateTime? _lastSampleTime;

  double get elapsedRaceTimeSec => _elapsedRaceTime;

  double? get avgFuelPerLap =>
      _fuelPerLapHistory.isEmpty ? null : _fuelPerLapHistory.reduce((a, b) => a + b) / _fuelPerLapHistory.length;

  double? get avgLapTimeSec =>
      _lapTimeHistory.isEmpty ? null : _lapTimeHistory.reduce((a, b) => a + b) / _lapTimeHistory.length;

  /// Feed one telemetry sample.
  void update({required int currentLap, required double? fuelPct}) {
    final now = DateTime.now();
    final dt = _lastSampleTime == null ? 0.0 : now.difference(_lastSampleTime!).inMicroseconds / 1e6;
    _lastSampleTime = now;
    _elapsedRaceTime += dt;

    if (_lastSeenLap != currentLap) {
      if (_lastSeenLap != null) {
        if (_fuelAtLapStart != null && fuelPct != null) {
          final used = _fuelAtLapStart! - fuelPct;
          if (used > 0) _pushHistory(_fuelPerLapHistory, used);
        }
        _pushHistory(_lapTimeHistory, _elapsedInLap);
      }
      _lastSeenLap = currentLap;
      _fuelAtLapStart = fuelPct;
      _elapsedInLap = 0;
    }

    _elapsedInLap += dt;
  }

  void _pushHistory(List<double> list, double value) {
    list.add(value);
    if (list.length > _rollingWindow) list.removeAt(0);
  }

  /// Null until there's both a usable race config and enough lap history to estimate
  /// from (at least one completed lap, so fuel-per-lap/lap-time have a real sample).
  FuelCalculatorResult? compute({required int currentLap, required double? fuelPct}) {
    final cfg = config;
    if (cfg == null || !(cfg.isTimedRace || cfg.isLapRace) || fuelPct == null) return null;

    int remainingLaps;
    if (cfg.isLapRace) {
      remainingLaps = math.max(0, cfg.totalLaps! - currentLap);
    } else {
      final avgLap = avgLapTimeSec;
      if (avgLap == null || avgLap <= 0) return null;
      final durationSec = cfg.durationMinutes! * 60;
      final remainingTime = durationSec - _elapsedRaceTime;
      remainingLaps = remainingTime <= 0 ? 0 : (remainingTime / avgLap).ceil();
    }

    final fuelPerLap = avgFuelPerLap;
    if (fuelPerLap == null) return null;

    final fuelNeeded = (remainingLaps + _safetyMarginLaps) * fuelPerLap;
    return FuelCalculatorResult(
      remainingLaps: remainingLaps,
      fuelNeededPct: fuelNeeded,
      fuelDeficitPct: fuelNeeded - fuelPct,
    );
  }
}
