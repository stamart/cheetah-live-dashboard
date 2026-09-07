import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../gt7/gt7_telemetry.dart';

/// Throttles the 60Hz GT7 telemetry stream down to a fixed send rate — the
/// backend and OBS overlay don't need every packet, just a smooth-looking
/// update a few times a second. Coalesces: only the latest sample since the
/// last tick is sent, intermediate ones are dropped rather than queued.
class TelemetryUplink {
  TelemetryUplink({
    required this.backendBaseUrl,
    required this.ingestToken,
    this.interval = const Duration(milliseconds: 150),
    this.onResult,
  });

  final String backendBaseUrl;
  final String ingestToken;
  final Duration interval;
  final void Function(bool ok, String? error)? onResult;

  Gt7Telemetry? _latest;
  Timer? _timer;
  bool _inFlight = false;

  void update(Gt7Telemetry telemetry) {
    _latest = telemetry;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _flush() async {
    final telemetry = _latest;
    if (telemetry == null || _inFlight) return;
    _inFlight = true;
    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/livetiming/ingest'),
            headers: {
              'Content-Type': 'application/json',
              'X-Ingest-Token': ingestToken,
            },
            body: jsonEncode({
              'speedKph': telemetry.speedKph,
              'rpm': telemetry.rpm.round(),
              'currentLap': telemetry.currentLap,
              'lastLapTimeMs': telemetry.lastLapTimeMs,
              'bestLapTimeMs': telemetry.bestLapTimeMs,
              'fuelPct': telemetry.fuelPct,
              'throttle': telemetry.throttlePct,
              'brake': telemetry.brakePct,
            }),
          )
          .timeout(const Duration(seconds: 5));
      onResult?.call(response.statusCode == 204, response.statusCode == 204 ? null : response.body);
    } catch (e) {
      onResult?.call(false, e.toString());
    } finally {
      _inFlight = false;
    }
  }
}
