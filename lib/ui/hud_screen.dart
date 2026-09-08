import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../backend/app_session_client.dart';
import '../backend/app_token_store.dart';
import '../backend/discord_auth_client.dart';
import '../backend/pairing_client.dart';
import '../backend/telemetry_uplink.dart';
import '../gt7/gt7_socket.dart';
import '../gt7/gt7_telemetry.dart';
import '../layouts/dashboard_landscape_layout.dart';
import '../layouts/dashboard_portrait_layout.dart';
import '../theme/app_colors.dart';

const _kPrefPs5Ip = 'ps5_ip';
const _kPrefBackendUrl = 'backend_url';

class BackendServerOption {
  final String label;
  final String url;
  const BackendServerOption(this.label, this.url);
}

const _kBackendServers = [
  BackendServerOption('Produkcja', 'https://backend.wificorp.pl'),
  BackendServerOption('Dev', 'http://192.168.1.9:8189'),
  BackendServerOption('Local', 'http://192.168.1.12:8080'),
];
final _kDefaultBackendUrl = _kBackendServers.first.url;

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

enum _SessionState { setup, connecting, live, error }

class _HudScreenState extends State<HudScreen> {
  final _ps5IpController = TextEditingController();
  final _tokenStore = AppTokenStore();
  String _backendUrl = _kDefaultBackendUrl;

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

  // Discord login state — replaces pairing codes.
  String? _appToken;
  String? _driverName;
  bool _loggingIn = false;
  List<JoinableEvent>? _joinableEvents;
  bool _loadingEvents = false;
  String? _eventsError;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the screen awake from launch, not just after pairing
    _loadPrefs();
    _loadStoredAuth();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedBackendUrl = prefs.getString(_kPrefBackendUrl);
    setState(() {
      _ps5IpController.text = prefs.getString(_kPrefPs5Ip) ?? '';
      _backendUrl = _kBackendServers.any((s) => s.url == storedBackendUrl)
          ? storedBackendUrl!
          : _kDefaultBackendUrl;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPs5Ip, _ps5IpController.text.trim());
    await prefs.setString(_kPrefBackendUrl, _backendUrl);
  }

  Future<void> _loadStoredAuth() async {
    final token = await _tokenStore.readToken();
    final name = await _tokenStore.readDriverName();
    if (token == null || !mounted) return;
    setState(() {
      _appToken = token;
      _driverName = name;
    });
    _loadJoinableEvents();
  }

  Future<void> _loginWithDiscord() async {
    final backendUrl = _backendUrl;

    setState(() {
      _loggingIn = true;
      _errorMessage = null;
    });

    try {
      final result = await DiscordAuthClient().login(backendUrl);
      await _tokenStore.save(token: result.appToken, driverName: result.driverName, driverId: result.driverId);
      if (!mounted) return;
      setState(() {
        _appToken = result.appToken;
        _driverName = result.driverName;
        _loggingIn = false;
      });
      _loadJoinableEvents();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loggingIn = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    final token = _appToken;
    if (token != null) {
      await AppSessionClient(_backendUrl).logout(token);
    }
    await _tokenStore.clear();
    if (!mounted) return;
    setState(() {
      _appToken = null;
      _driverName = null;
      _joinableEvents = null;
      _eventsError = null;
    });
  }

  Future<void> _loadJoinableEvents() async {
    final token = _appToken;
    if (token == null) return;

    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });

    try {
      final events = await AppSessionClient(_backendUrl).listJoinableEvents(token);
      if (!mounted) return;
      setState(() {
        _joinableEvents = events;
        _loadingEvents = false;
      });
    } on AppTokenExpiredException {
      await _handleExpiredToken();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _eventsError = 'Nie udało się pobrać listy eventów: $e';
      });
    }
  }

  Future<void> _handleExpiredToken() async {
    await _tokenStore.clear();
    if (!mounted) return;
    setState(() {
      _appToken = null;
      _driverName = null;
      _joinableEvents = null;
      _loadingEvents = false;
      _errorMessage = 'Sesja logowania wygasła — zaloguj się ponownie przez Discord.';
    });
  }

  Future<void> _connect({int? eventId}) async {
    final ps5Ip = _ps5IpController.text.trim();
    final backendUrl = _backendUrl;
    final appToken = _appToken;

    if (ps5Ip.isEmpty) {
      setState(() {
        _state = _SessionState.error;
        _errorMessage = 'Uzupełnij adres IP PS5.';
      });
      return;
    }
    if (appToken == null) {
      setState(() {
        _state = _SessionState.error;
        _errorMessage = 'Zaloguj się przez Discord przed połączeniem.';
      });
      return;
    }

    await _savePrefs();
    setState(() {
      _state = _SessionState.connecting;
      _errorMessage = null;
    });

    try {
      final session = await AppSessionClient(backendUrl).startSession(appToken, eventId: eventId);

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

      setState(() {
        _gt7Socket = gt7;
        _uplink = uplink;
        _session = session;
        _state = _SessionState.live;
      });
    } on AppTokenExpiredException {
      await _handleExpiredToken();
      setState(() => _state = _SessionState.setup);
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
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = _latestTelemetry;
    if (_state == _SessionState.live && telemetry != null) {
      return _buildLiveDashboard(telemetry);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Cheetah Live')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _state == _SessionState.live ? _buildWaitingShell() : _buildSetup(),
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
        DropdownButtonFormField<String>(
          initialValue: _backendUrl,
          decoration: const InputDecoration(labelText: 'Adres serwera Cheetah'),
          items: _kBackendServers
              .map((s) => DropdownMenuItem(value: s.url, child: Text('${s.label} — ${s.url}')))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _backendUrl = value);
            _savePrefs();
          },
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        if (_appToken == null) _buildLoginPrompt() else _buildLoggedInPicker(),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return FilledButton.icon(
      onPressed: _loggingIn ? null : _loginWithDiscord,
      icon: _loggingIn
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.discord),
      label: const Text('Zaloguj przez Discord'),
    );
  }

  Widget _buildLoggedInPicker() {
    final connecting = _state == _SessionState.connecting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Zalogowano jako $_driverName', style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton(onPressed: connecting ? null : _logout, child: const Text('Wyloguj')),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: connecting ? null : () => _connect(),
          child: connecting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Połącz — wolny tryb'),
        ),
        const SizedBox(height: 20),
        Text('Albo dołącz do eventu:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        _buildEventsList(connecting),
      ],
    );
  }

  Widget _buildEventsList(bool connecting) {
    if (_loadingEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_eventsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_eventsError!, style: const TextStyle(color: Colors.orange)),
          TextButton(onPressed: _loadJoinableEvents, child: const Text('Spróbuj ponownie')),
        ],
      );
    }
    final events = _joinableEvents;
    if (events == null || events.isEmpty) {
      return const Text('Brak dostępnych eventów.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: events
          .map((e) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.sim}${e.startAt != null ? ' • ${_fmtEventTime(e.startAt!)}' : ''}'),
                  onTap: connecting ? null : () => _connect(eventId: e.id),
                ),
              ))
          .toList(),
    );
  }

  String _fmtEventTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  /// Shown once pairing succeeds but before GT7 has sent its first packet — the live
  /// dashboard (see _buildLiveDashboard) takes over the instant telemetry starts flowing.
  /// Without this shell, a paired-but-no-telemetry-yet session looked identical to the
  /// initial unconnected setup screen, with no indication anything had happened.
  Widget _buildWaitingShell() {
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
        Expanded(child: _buildWaitingForTelemetry()),
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

  /// GT7's own min/max alert RPM define the gauge's colored zones — fall back to sane
  /// defaults only for the rare case they read as 0 (e.g. the very first packet, or a
  /// menu/replay state before the game populates them for the current car).
  double get _gaugeMinAlertRpm {
    final v = _latestTelemetry?.minAlertRpm ?? 0;
    return v > 0 ? v : 7000;
  }

  double get _gaugeMaxAlertRpm {
    final v = _latestTelemetry?.maxAlertRpm ?? 0;
    final minAlert = _gaugeMinAlertRpm;
    return v > minAlert ? v : minAlert + 1500;
  }

  /// GT7 doesn't send an explicit "gauge max" distinct from the redline threshold — add a
  /// little headroom above maxAlertRpm so the red zone has visible width, same as the
  /// reference design.
  double get _gaugeMaxRpm => _gaugeMaxAlertRpm + (_gaugeMaxAlertRpm - _gaugeMinAlertRpm) * 0.15;

  /// Full-bleed HUD dashboard — takes over the whole screen (its own Scaffold, no AppBar)
  /// once telemetry is actually flowing. Same widgets/layouts as the static preview
  /// (lib/screens/dashboard_screen.dart), just fed from the live GT7 stream.
  Widget _buildLiveDashboard(Gt7Telemetry t) {
    final driverName = _session?.driverName ?? _driverName ?? '—';
    final ps5Ip = _ps5IpForDisplay;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            // Landscape is the "racing" view — auto-fullscreen (hide Android's status/nav
            // bars) since there's no in-app top bar there to compete with them for space.
            // Portrait keeps the normal system UI. setEnabledSystemUIMode is cheap/idempotent
            // to call repeatedly, so doing it here on every rebuild is fine.
            SystemChrome.setEnabledSystemUIMode(
              orientation == Orientation.landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
            );
            return orientation == Orientation.landscape
                ? DashboardLandscapeLayout(
                    driverName: driverName,
                    ps5Ip: ps5Ip,
                    ps5Online: _ps5Connected,
                    serverOnline: _lastIngestOk,
                    wifiConnected: true,
                    onDisconnect: _disconnect,
                    currentLap: t.currentLap,
                    totalLaps: t.totalLaps,
                    lastLapTime: _fmtLap(t.lastLapTimeMs),
                    bestLapTime: _fmtLap(t.bestLapTimeMs),
                    currentRpm: t.rpm,
                    maxRpm: _gaugeMaxRpm,
                    minAlertRpm: _gaugeMinAlertRpm,
                    maxAlertRpm: _gaugeMaxAlertRpm,
                    gear: t.gear,
                    speedKmh: t.speedKph,
                    fuelPct: t.fuelPct,
                    tireTempFL: t.tireTempFL,
                    tireTempFR: t.tireTempFR,
                    tireTempRL: t.tireTempRL,
                    tireTempRR: t.tireTempRR,
                  )
                : DashboardPortraitLayout(
                    driverName: driverName,
                    ps5Ip: ps5Ip,
                    ps5Online: _ps5Connected,
                    serverOnline: _lastIngestOk,
                    wifiConnected: true,
                    onDisconnect: _disconnect,
                    currentLap: t.currentLap,
                    totalLaps: t.totalLaps,
                    lastLapTime: _fmtLap(t.lastLapTimeMs),
                    bestLapTime: _fmtLap(t.bestLapTimeMs),
                    currentRpm: t.rpm,
                    maxRpm: _gaugeMaxRpm,
                    minAlertRpm: _gaugeMinAlertRpm,
                    maxAlertRpm: _gaugeMaxAlertRpm,
                    gear: t.gear,
                    speedKmh: t.speedKph,
                    fuelPct: t.fuelPct,
                    tireTempFL: t.tireTempFL,
                    tireTempFR: t.tireTempFR,
                    tireTempRL: t.tireTempRL,
                    tireTempRR: t.tireTempRR,
                  );
          },
        ),
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
