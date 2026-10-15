import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../backend/app_session_client.dart';
import '../backend/app_token_store.dart';
import '../backend/discord_auth_client.dart';
import '../backend/pairing_client.dart';
import '../backend/telemetry_uplink.dart';
import '../gt7/fuel_calculator.dart';
import '../gt7/gt7_socket.dart';
import '../gt7/gt7_telemetry.dart';
import '../gt7/gt7_telemetry_simulator.dart';
import '../gt7/lap_delta_tracker.dart';
import '../i18n/app_strings.dart';
import '../layouts/dashboard_landscape_layout.dart';
import '../layouts/dashboard_portrait_layout.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard/session_config_sheet.dart';
import 'session_wizard.dart';

const _kPrefPs5Ip = 'ps5_ip';
const _kPrefBackendUrl = 'backend_url';
const _kPrefLang = 'app_lang';

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
  AppLang _lang = AppLang.pl;
  AppStrings get s => AppStrings(_lang);

  Gt7Socket? _gt7Socket;
  TelemetryUplink? _uplink;
  StreamSubscription<Gt7Telemetry>? _telemetrySub;
  StreamSubscription<bool>? _ps5ConnSub;
  Gt7TelemetrySimulator? _demoSimulator;
  StreamSubscription<Gt7Telemetry>? _demoSub;

  _SessionState _state = _SessionState.setup;
  String? _errorMessage;
  Gt7Telemetry? _latestTelemetry;
  bool _ps5Connected = false;
  bool _lastIngestOk = true;
  PairingResult? _session;
  final _lapDeltaTracker = LapDeltaTracker();
  double? _deltaSeconds;
  final _fuelCalculator = FuelCalculator();
  RaceConfig? _raceConfig;
  bool _configPromptShown = false;
  Timer? _configPromptTimer;

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
    // keep the screen awake from launch, not just after pairing — on web, the Wake Lock API
    // rejects if the tab isn't visible (e.g. focus moved to the Discord login tab), so this
    // must not be allowed to surface as an uncaught error
    WakelockPlus.enable().catchError((_) {});
    _loadPrefs();
    _loadStoredAuth();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedBackendUrl = prefs.getString(_kPrefBackendUrl);
    final storedLang = prefs.getString(_kPrefLang);
    setState(() {
      _ps5IpController.text = prefs.getString(_kPrefPs5Ip) ?? '';
      _backendUrl = _kBackendServers.any((o) => o.url == storedBackendUrl)
          ? storedBackendUrl!
          : _kDefaultBackendUrl;
      _lang = storedLang == 'en' ? AppLang.en : AppLang.pl;
    });
  }

  void _setLang(AppLang lang) {
    setState(() => _lang = lang);
    SharedPreferences.getInstance().then((p) => p.setString(_kPrefLang, lang == AppLang.en ? 'en' : 'pl'));
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
        _errorMessage = s.missingPs5Ip;
      });
      return;
    }
    if (appToken == null) {
      setState(() {
        _state = _SessionState.error;
        _errorMessage = s.loginBeforeConnect;
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
        final delta = _lapDeltaTracker.update(t);
        _fuelCalculator.update(currentLap: t.currentLap, fuelPct: t.fuelPct);
        if (!mounted) return;
        setState(() {
          _latestTelemetry = t;
          _deltaSeconds = delta;
        });
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
      _maybeShowSessionConfigPrompt();
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

  /// Demo mode — no PS5, no backend, no network at all. Feeds a synthetic telemetry
  /// stream through the exact same live-dashboard pipeline as a real session, so the
  /// dashboard can be shown/reviewed without any hardware (Play Store review has no PS5
  /// to connect to; this is also just handy for showing someone the app).
  void _startDemo() {
    final sim = Gt7TelemetrySimulator()..start();
    _demoSub = sim.telemetry.listen((t) {
      final delta = _lapDeltaTracker.update(t);
      _fuelCalculator.update(currentLap: t.currentLap, fuelPct: t.fuelPct);
      if (!mounted) return;
      setState(() {
        _latestTelemetry = t;
        _deltaSeconds = delta;
      });
    });
    setState(() {
      _demoSimulator = sim;
      _ps5Connected = true;
      _lastIngestOk = true;
      _state = _SessionState.live;
    });
    _maybeShowSessionConfigPrompt();
  }

  /// Shown once per session, only the first time the live dashboard is reached — an
  /// auto-dismissing (10s) prompt for the driver to set session type / race format, since
  /// GT7 telemetry has none of this (see docs/superpowers/plans in the main monorepo,
  /// item 18). Skipped entirely once already shown/answered this session; the driver can
  /// still open the same sheet any time via the persistent fuel-calculator chip.
  void _maybeShowSessionConfigPrompt() {
    if (_configPromptShown) return;
    _configPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSessionConfigSheet(autoDismiss: true));
  }

  Future<void> _openSessionConfigSheet({bool autoDismiss = false}) async {
    if (!mounted) return;
    if (autoDismiss) {
      _configPromptTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
    final cfg = await SessionConfigSheet.show(context);
    _configPromptTimer?.cancel();
    if (cfg != null && mounted) {
      setState(() {
        _raceConfig = cfg;
        _fuelCalculator.config = cfg;
      });
    }
  }

  Future<void> _disconnect() async {
    await _telemetrySub?.cancel();
    await _ps5ConnSub?.cancel();
    await _demoSub?.cancel();
    _uplink?.stop();
    _gt7Socket?.dispose();
    _demoSimulator?.dispose();
    _configPromptTimer?.cancel();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() {
      _gt7Socket = null;
      _uplink = null;
      _session = null;
      _latestTelemetry = null;
      _ps5Connected = false;
      _demoSimulator = null;
      _raceConfig = null;
      _fuelCalculator.config = null;
      _configPromptShown = false;
      _state = _SessionState.setup;
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _ps5ConnSub?.cancel();
    _demoSub?.cancel();
    _uplink?.stop();
    _gt7Socket?.dispose();
    _demoSimulator?.dispose();
    _configPromptTimer?.cancel();
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
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Container(height: 2, color: AppColors.borderGray),
              const SizedBox(height: 20),
              Expanded(
                child: _state == _SessionState.live ? _buildWaitingShell() : _buildSetup(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Image.asset('assets/branding/cheetah-badge.png', height: 44),
        const SizedBox(width: 14),
        Image.asset('assets/branding/cheetah-wordmark.png', height: 20),
        const Spacer(),
        _LangPill(label: 'PL', selected: _lang == AppLang.pl, onTap: () => _setLang(AppLang.pl)),
        const SizedBox(width: 8),
        _LangPill(label: 'EN', selected: _lang == AppLang.en, onTap: () => _setLang(AppLang.en)),
      ],
    );
  }

  Widget _buildSetup() {
    return ListView(
      children: [
        _OutlineActionButton(
          onTap: _startDemo,
          icon: Icons.play_circle_outline,
          label: s.demoMode,
        ),
        const SizedBox(height: 28),
        _LabeledField(
          label: s.ps5IpLabel,
          child: TextField(
            controller: _ps5IpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '192.168.1.150',
              hintStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          _LabeledField(
            label: s.serverLabel,
            child: DropdownButtonFormField<String>(
              initialValue: _backendUrl,
              isExpanded: true,
              dropdownColor: AppColors.bgCard,
              icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
              style: const TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              items: _kBackendServers
                  .map((s) => DropdownMenuItem(value: s.url, child: Text('${s.label} — ${s.url}')))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _backendUrl = value);
                _savePrefs();
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_errorMessage!, style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600)),
          ),
        if (_appToken == null) _buildLoginPrompt() else _buildLoggedInPicker(),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return _SolidActionButton(
      onTap: _loggingIn ? null : _loginWithDiscord,
      icon: _loggingIn ? null : Icons.discord,
      label: s.loginWithDiscord,
      loading: _loggingIn,
    );
  }

  Widget _buildLoggedInPicker() {
    final connecting = _state == _SessionState.connecting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 22, color: AppColors.accentYellow),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${s.loggedInAs} $_driverName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: connecting ? null : _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentYellow,
                side: const BorderSide(color: AppColors.borderGray),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(s.logout),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SolidActionButton(
          onTap: connecting ? null : _openFreerideWizard,
          icon: connecting ? null : Icons.chevron_right,
          label: s.connectFreeride,
          loading: connecting,
        ),
        const SizedBox(height: 24),
        Text(s.orJoinEvent, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _buildEventsList(connecting),
      ],
    );
  }

  /// Freeride entry point now opens the session-config wizard (continent → track →
  /// layout → session type/format → tyres) instead of connecting immediately — track/tyre
  /// choices are local/informational for now (GT7 itself dictates the real car/track once
  /// telemetry flows), but the session-type/format step feeds straight into [RaceConfig],
  /// so completing the wizard also answers the fuel calculator's config prompt.
  Future<void> _openFreerideWizard() async {
    final result = await Navigator.of(context).push<SessionWizardResult>(
      MaterialPageRoute(builder: (_) => SessionWizard(lang: _lang)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _raceConfig = result.raceConfig;
      _fuelCalculator.config = result.raceConfig;
    });
    _connect();
  }

  Widget _buildEventsList(bool connecting) {
    if (_loadingEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentYellow),
        ),
      );
    }
    if (_eventsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_eventsError!, style: const TextStyle(color: AppColors.accentOrange)),
          TextButton(
            onPressed: _loadJoinableEvents,
            style: TextButton.styleFrom(foregroundColor: AppColors.accentYellow),
            child: Text(s.retry),
          ),
        ],
      );
    }
    final events = _joinableEvents;
    if (events == null || events.isEmpty) {
      return Text(s.noEvents, style: const TextStyle(color: AppColors.textMuted));
    }
    return Column(
      children: events
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventCard(
                  name: e.name,
                  subtitle: '${e.sim}${e.startAt != null ? ' • ${_fmtEventTime(e.startAt!)}' : ''}',
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
          children: [
            Expanded(
              child: Text(
                _session?.eventName ?? s.freerideSession,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _disconnect,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentYellow,
                side: const BorderSide(color: AppColors.borderGray),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(s.disconnect),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${s.driverLabel}: ${_session?.driverName ?? '—'}', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(
          children: [
            _statusDot(_ps5Connected, s.ps5),
            const SizedBox(width: 32),
            _statusDot(_lastIngestOk, s.server),
          ],
        ),
        const SizedBox(height: 20),
        Container(height: 2, color: AppColors.borderGray),
        Expanded(child: _buildWaitingForTelemetry()),
      ],
    );
  }

  Widget _buildWaitingForTelemetry() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accentYellow),
            const SizedBox(height: 24),
            Text(
              s.waitingForGt7(_ps5Connected, _ps5IpForDisplay),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              s.waitingHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
    final fuelResult = _fuelCalculator.compute(currentLap: t.currentLap, fuelPct: t.fuelPct);
    final raceConfig = _raceConfig;
    final remainingRaceSeconds = raceConfig != null && raceConfig.isTimedRace
        ? (raceConfig.durationMinutes! * 60) - _fuelCalculator.elapsedRaceTimeSec
        : null;
    final effectiveTotalLaps = raceConfig != null && raceConfig.isLapRace ? raceConfig.totalLaps! : t.totalLaps;
    final avgFuelPerLap = _fuelCalculator.avgFuelPerLap;
    final lapsOnCurrentFuel = (t.fuelPct != null && avgFuelPerLap != null && avgFuelPerLap > 0)
        ? (t.fuelPct! / avgFuelPerLap).floor()
        : null;

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
                    ps5Online: _ps5Connected,
                    serverOnline: _lastIngestOk,
                    onDisconnect: _disconnect,
                    currentLap: t.currentLap,
                    totalLaps: effectiveTotalLaps,
                    lastLapTime: _fmtLap(t.lastLapTimeMs),
                    bestLapTime: _fmtLap(t.bestLapTimeMs),
                    currentRpm: t.rpm,
                    maxRpm: _gaugeMaxRpm,
                    minAlertRpm: _gaugeMinAlertRpm,
                    maxAlertRpm: _gaugeMaxAlertRpm,
                    gear: t.gear,
                    speedKmh: t.speedKph,
                    fuelPct: t.fuelPct,
                    deltaSeconds: _deltaSeconds,
                    raceConfig: raceConfig,
                    fuelResult: fuelResult,
                    lapsOnCurrentFuel: lapsOnCurrentFuel,
                    remainingRaceSeconds: remainingRaceSeconds,
                    onFuelChipTap: () => _openSessionConfigSheet(),
                    tireTempFL: t.tireTempFL,
                    tireTempFR: t.tireTempFR,
                    tireTempRL: t.tireTempRL,
                    tireTempRR: t.tireTempRR,
                    throttlePct: t.throttlePct,
                    brakePct: t.brakePct,
                  )
                : DashboardPortraitLayout(
                    ps5Online: _ps5Connected,
                    serverOnline: _lastIngestOk,
                    onDisconnect: _disconnect,
                    currentLap: t.currentLap,
                    totalLaps: effectiveTotalLaps,
                    lastLapTime: _fmtLap(t.lastLapTimeMs),
                    bestLapTime: _fmtLap(t.bestLapTimeMs),
                    currentRpm: t.rpm,
                    maxRpm: _gaugeMaxRpm,
                    minAlertRpm: _gaugeMinAlertRpm,
                    maxAlertRpm: _gaugeMaxAlertRpm,
                    gear: t.gear,
                    speedKmh: t.speedKph,
                    fuelPct: t.fuelPct,
                    deltaSeconds: _deltaSeconds,
                    raceConfig: raceConfig,
                    fuelResult: fuelResult,
                    lapsOnCurrentFuel: lapsOnCurrentFuel,
                    remainingRaceSeconds: remainingRaceSeconds,
                    onFuelChipTap: () => _openSessionConfigSheet(),
                    tireTempFL: t.tireTempFL,
                    tireTempFR: t.tireTempFR,
                    tireTempRL: t.tireTempRL,
                    tireTempRR: t.tireTempRR,
                    throttlePct: t.throttlePct,
                    brakePct: t.brakePct,
                  );
          },
        ),
      ),
    );
  }

  Widget _statusDot(bool ok, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: ok ? AppColors.accentGreen : AppColors.accentRed),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
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

/// Small caption above a value — the "label above underline, big bold value below" field
/// style used throughout the setup screen (PS5 IP, server picker).
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 8),
        Container(height: 2, color: AppColors.borderGray),
      ],
    );
  }
}

/// Outlined yellow button — used for the demo-mode entry point, a lower-emphasis action
/// than the solid Discord/connect buttons.
class _OutlineActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;

  const _OutlineActionButton({required this.onTap, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(border: Border.all(color: AppColors.accentYellow, width: 2)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accentYellow, size: 26),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(color: AppColors.accentYellow, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solid yellow full-width button — the primary action on each setup-screen state
/// (Discord login, connect). Shows a spinner in place of the icon while [loading].
class _SolidActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final String label;
  final bool loading;

  const _SolidActionButton({required this.onTap, required this.icon, required this.label, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentYellow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                )
              else if (icon != null)
                Icon(icon, color: Colors.black, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PL/EN language pill in the header — matches the reference design's language switch.
class _LangPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentYellow : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderGray, width: 2)),
          child: Text(
            label,
            style: TextStyle(color: selected ? Colors.black : AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

/// Bordered joinable-event card in the event list.
class _EventCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;

  const _EventCard({required this.name, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderGray, width: 2)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
