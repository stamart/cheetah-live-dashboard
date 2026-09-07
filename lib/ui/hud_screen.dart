import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../backend/pairing_client.dart';
import '../backend/telemetry_uplink.dart';
import '../gt7/gt7_socket.dart';
import '../gt7/gt7_telemetry.dart';

const _kPrefPs5Ip = 'ps5_ip';
const _kPrefBackendUrl = 'backend_url';
const _kDefaultBackendUrl = 'https://backend.wificorp.pl';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

enum _SessionState { setup, connecting, live, error }

class _HudScreenState extends State<HudScreen> {
  final _ps5IpController = TextEditingController();
  final _backendUrlController = TextEditingController(text: _kDefaultBackendUrl);
  final _pairingCodeController = TextEditingController();

  Gt7Socket? _gt7Socket;
  TelemetryUplink? _uplink;
  StreamSubscription<Gt7Telemetry>? _telemetrySub;
  StreamSubscription<bool>? _ps5ConnSub;

  _SessionState _state = _SessionState.setup;
  String? _errorMessage;
  Gt7Telemetry? _latestTelemetry;
  bool _ps5Connected = false;
  bool _lastIngestOk = true;
  PairingResult? _session;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ps5IpController.text = prefs.getString(_kPrefPs5Ip) ?? '';
      _backendUrlController.text = prefs.getString(_kPrefBackendUrl) ?? _kDefaultBackendUrl;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPs5Ip, _ps5IpController.text.trim());
    await prefs.setString(_kPrefBackendUrl, _backendUrlController.text.trim());
  }

  Future<void> _connect() async {
    final ps5Ip = _ps5IpController.text.trim();
    final backendUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    final pairingCode = _pairingCodeController.text.trim();

    if (ps5Ip.isEmpty || backendUrl.isEmpty || pairingCode.isEmpty) {
      setState(() {
        _state = _SessionState.error;
        _errorMessage = 'Uzupełnij adres IP PS5, adres serwera i kod parowania.';
      });
      return;
    }

    await _savePrefs();
    setState(() {
      _state = _SessionState.connecting;
      _errorMessage = null;
    });

    try {
      final session = await PairingClient(backendUrl).exchange(pairingCode);

      final gt7 = Gt7Socket(ps5Ip);
      await gt7.start();

      final uplink = TelemetryUplink(
        backendBaseUrl: backendUrl,
        ingestToken: session.ingestToken,
        onResult: (ok, error) {
          if (!mounted) return;
          setState(() => _lastIngestOk = ok);
        },
      );
      uplink.start();

      _telemetrySub = gt7.telemetry.listen((t) {
        uplink.update(t);
        if (!mounted) return;
        setState(() => _latestTelemetry = t);
      });
      _ps5ConnSub = gt7.connectionStatus.listen((connected) {
        if (!mounted) return;
        setState(() => _ps5Connected = connected);
      });

      await WakelockPlus.enable();

      setState(() {
        _gt7Socket = gt7;
        _uplink = uplink;
        _session = session;
        _state = _SessionState.live;
      });
    } catch (e) {
      setState(() {
        _state = _SessionState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _disconnect() async {
    await _telemetrySub?.cancel();
    await _ps5ConnSub?.cancel();
    _uplink?.stop();
    _gt7Socket?.dispose();
    await WakelockPlus.disable();
    setState(() {
      _gt7Socket = null;
      _uplink = null;
      _session = null;
      _latestTelemetry = null;
      _ps5Connected = false;
      _state = _SessionState.setup;
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _ps5ConnSub?.cancel();
    _uplink?.stop();
    _gt7Socket?.dispose();
    _ps5IpController.dispose();
    _backendUrlController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cheetah Live')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _state == _SessionState.live ? _buildLive() : _buildSetup(),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return ListView(
      children: [
        TextField(
          controller: _ps5IpController,
          decoration: const InputDecoration(
            labelText: 'Adres IP PS5 (ta sama sieć Wi-Fi)',
            hintText: '192.168.1.150',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _backendUrlController,
          decoration: const InputDecoration(labelText: 'Adres serwera Cheetah'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pairingCodeController,
          decoration: const InputDecoration(
            labelText: 'Kod parowania',
            hintText: 'Podany przez organizatora w panelu',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 20),
        if (_state == _SessionState.error && _errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        FilledButton(
          onPressed: _state == _SessionState.connecting ? null : _connect,
          child: _state == _SessionState.connecting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Połącz'),
        ),
      ],
    );
  }

  /// Live session shell — always shown once pairing succeeds, regardless of
  /// whether GT7 has sent its first packet yet. Without this, a paired-but-
  /// no-telemetry-yet session looked identical to the initial unconnected
  /// setup screen, with no indication anything had happened.
  Widget _buildLive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_session?.eventName ?? 'Sesja wolna (bez eventu)', style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: _disconnect, child: const Text('Rozłącz')),
          ],
        ),
        Text('Kierowca: ${_session?.driverName ?? '—'}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            _statusDot(_ps5Connected, 'PS5'),
            const SizedBox(width: 16),
            _statusDot(_lastIngestOk, 'Serwer'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _latestTelemetry == null ? _buildWaitingForTelemetry() : _buildHud(_latestTelemetry!),
        ),
      ],
    );
  }

  Widget _buildWaitingForTelemetry() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _ps5Connected ? 'Sparowano — czekam na dane z GT7...' : 'Sparowano z serwerem — łączę z PS5 pod $_ps5IpForDisplay...',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upewnij się, że GT7 jest uruchomione (nie tylko konsola) i telefon jest\n'
            'w tej samej sieci Wi-Fi co PS5.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String get _ps5IpForDisplay => _ps5IpController.text.trim();

  Widget _buildHud(Gt7Telemetry t) {
    return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.speedKph.round().toString(),
                  style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
                ),
                const Text('km/h', style: TextStyle(fontSize: 20, color: Colors.grey)),
                const SizedBox(height: 24),
                Text('RPM ${t.rpm.round()}', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text('Okrążenie ${t.currentLap}', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text('Ostatnie: ${_fmtLap(t.lastLapTimeMs)}   Najlepsze: ${_fmtLap(t.bestLapTimeMs)}',
                    style: const TextStyle(fontSize: 18)),
                if (t.fuelPct != null) ...[
                  const SizedBox(height: 8),
                  Text('Paliwo ${t.fuelPct!.round()}%', style: const TextStyle(fontSize: 18)),
                ],
              ],
            ),
          );
  }

  Widget _statusDot(bool ok, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: ok ? Colors.green : Colors.red, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  String _fmtLap(int? ms) {
    if (ms == null) return '—';
    final m = ms ~/ 60000;
    final s = (ms % 60000) / 1000;
    return '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
  }
}
