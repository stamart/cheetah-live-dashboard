import 'dart:math' as math;

import 'gt7_telemetry.dart';

class _DistTime {
  final double distance;
  final double elapsedSec;
  const _DistTime(this.distance, this.elapsedSec);
}

/// Computes a live delta (seconds) against the driver's own best lap — positive means
/// behind the best lap's pace at this point on track, negative means ahead. This only
/// needs data GT7 already gives us about our own car (position + lap boundaries), no
/// other-car data required.
///
/// How it works: every telemetry sample is recorded as (cumulative distance since this
/// lap started, elapsed time since this lap started). Distance is the running sum of
/// straight-line movement between consecutive samples in the XZ plane (Y is height, not
/// part of the track's 2D layout) — noisy compared to a true track-distance model, but
/// monotonic and good enough to interpolate a reference time at "roughly the same point
/// on track". When a lap finishes and it's a new personal best, its recorded curve
/// becomes the reference for [update] to compare subsequent laps against.
class LapDeltaTracker {
  int? _lastSeenLap;
  int? _bestLapMs;
  List<_DistTime> _currentLapSamples = [];
  List<_DistTime>? _bestLapSamples;

  double _cumulativeDistance = 0;
  double _elapsedInLap = 0;
  double? _lastX;
  double? _lastZ;
  DateTime? _lastSampleTime;
  double? _lastDelta;
  double? _lastRpm;
  int _frozenRpmStreak = 0;

  /// Consecutive samples with *bit-identical* RPM before we treat the sim as frozen (menu,
  /// pause, replay) rather than actually driving. Real engine simulation always has tiny
  /// frame-to-frame RPM jitter — even sitting still at idle — so more than a couple of
  /// exactly-equal readings in a row is a strong, fast signal that physics isn't running,
  /// independent of (and more reliable in practice than) the `isPaused` flag alone.
  static const int _frozenRpmThreshold = 3;

  /// Feed one telemetry sample; returns the current delta in seconds, or null if there's
  /// no best-lap reference yet (first lap since the tracker started, or no best lap set).
  double? update(Gt7Telemetry t) {
    final now = DateTime.now();
    final dt = _lastSampleTime == null ? 0.0 : now.difference(_lastSampleTime!).inMicroseconds / 1e6;
    _lastSampleTime = now;

    if (_lastSeenLap != t.currentLap) {
      _onLapBoundary(t);
    }

    _frozenRpmStreak = (t.rpm == _lastRpm) ? _frozenRpmStreak + 1 : 0;
    _lastRpm = t.rpm;

    // Don't accumulate elapsed time/distance while paused, or while the sim looks frozen
    // (menu, replay, loading) — otherwise real wall-clock time keeps ticking into the lap
    // timeline while the car isn't actually moving, which corrupts both the live delta and
    // any reference curve recorded during that stretch (flat "same distance, growing time"
    // runs that made the interpolated delta jump around wildly).
    if (t.isPaused || _frozenRpmStreak >= _frozenRpmThreshold) {
      return _lastDelta;
    }

    _elapsedInLap += dt;
    if (_lastX != null && _lastZ != null) {
      final dx = t.positionX - _lastX!;
      final dz = t.positionZ - _lastZ!;
      _cumulativeDistance += math.sqrt(dx * dx + dz * dz);
    }
    _lastX = t.positionX;
    _lastZ = t.positionZ;

    _currentLapSamples.add(_DistTime(_cumulativeDistance, _elapsedInLap));

    final best = _bestLapSamples;
    if (best == null || best.isEmpty) {
      _lastDelta = null;
      return null;
    }
    final refTime = _interpolate(best, _cumulativeDistance);
    _lastDelta = _elapsedInLap - refTime;
    return _lastDelta;
  }

  void _onLapBoundary(Gt7Telemetry t) {
    if (_lastSeenLap != null && t.lastLapTimeMs != null) {
      if (_bestLapMs == null || t.lastLapTimeMs! < _bestLapMs!) {
        _bestLapMs = t.lastLapTimeMs;
        _bestLapSamples = _currentLapSamples;
      }
    }
    _lastSeenLap = t.currentLap;
    _currentLapSamples = [];
    _cumulativeDistance = 0;
    _elapsedInLap = 0;
    _lastX = null;
    _lastZ = null;
  }

  /// Linear interpolation of elapsed time at [distance] along the reference curve.
  /// Distance is monotonically increasing in [samples] by construction.
  double _interpolate(List<_DistTime> samples, double distance) {
    if (distance <= samples.first.distance) return samples.first.elapsedSec;
    if (distance >= samples.last.distance) return samples.last.elapsedSec;

    var lo = 0;
    var hi = samples.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (samples[mid].distance <= distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = samples[lo];
    final b = samples[hi];
    final span = b.distance - a.distance;
    if (span <= 0) return a.elapsedSec;
    final frac = (distance - a.distance) / span;
    return a.elapsedSec + frac * (b.elapsedSec - a.elapsedSec);
  }
}
