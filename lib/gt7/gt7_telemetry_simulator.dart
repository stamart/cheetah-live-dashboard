import 'dart:async';
import 'dart:math' as math;

import 'gt7_telemetry.dart';

/// Generates a plausible, continuously-animating fake telemetry stream — no PS5, no
/// backend, no network at all. Exists so the dashboard can be demonstrated (Play Store
/// reviewers with no console to hand, or any driver just showing someone the app) without
/// requiring real hardware. Values are pure sine/sawtooth animation, not a physics sim —
/// only meant to look alive on the dashboard, not to be accurate.
class Gt7TelemetrySimulator {
  static const double _maxRpm = 8000;
  static const double _minAlertRpm = 6800;
  static const double _maxAlertRpm = 7600;
  static const double _lapSeconds = 95;

  Timer? _timer;
  final _controller = StreamController<Gt7Telemetry>.broadcast();
  final _stopwatch = Stopwatch();
  int _lap = 1;
  double _fuel = 100;

  Stream<Gt7Telemetry> get telemetry => _controller.stream;

  void start() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _tick() {
    final t = _stopwatch.elapsedMilliseconds / 1000.0;

    final lapPhase = (t % _lapSeconds) / _lapSeconds;
    final lapNumber = 1 + (t / _lapSeconds).floor();
    if (lapNumber != _lap) _lap = lapNumber;

    final gear = 1 + ((t % 6) / 6 * 6).floor().clamp(0, 5);
    final revPhase = (math.sin(t * 1.4) + 1) / 2;
    final rpm = 1200 + revPhase * (_maxRpm - 1200);
    final speed = (gear * 28.0) * (0.4 + revPhase * 0.6);

    _fuel = (100 - lapPhase * 4 - (_lap - 1) * 2).clamp(5, 100);

    final throttle = (math.sin(t * 1.4) * 0.5 + 0.5) * 100;
    final brake = (100 - throttle) * 0.3;

    _controller.add(Gt7Telemetry(
      speedKph: speed,
      rpm: rpm,
      gear: gear,
      minAlertRpm: _minAlertRpm,
      maxAlertRpm: _maxAlertRpm,
      currentLap: _lap,
      totalLaps: 0,
      lastLapTimeMs: _lap > 1 ? 96500 + ((t * 37).toInt() % 3000) : null,
      bestLapTimeMs: _lap > 1 ? 96500 : null,
      fuelPct: _fuel,
      throttlePct: throttle,
      brakePct: brake,
      inRace: true,
      isPaused: false,
      tireTempFL: 78 + math.sin(t * 0.3) * 6,
      tireTempFR: 79 + math.sin(t * 0.31) * 6,
      tireTempRL: 74 + math.sin(t * 0.29) * 6,
      tireTempRR: 75 + math.sin(t * 0.32) * 6,
      positionX: math.cos(lapPhase * 2 * math.pi) * 500,
      positionY: 0,
      positionZ: math.sin(lapPhase * 2 * math.pi) * 500,
    ));
  }
}
