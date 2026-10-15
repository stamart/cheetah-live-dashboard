import 'package:flutter/material.dart';

import '../gt7/fuel_calculator.dart';
import '../i18n/app_strings.dart';
import '../theme/app_colors.dart';

class SessionWizardResult {
  final RaceConfig raceConfig;
  final String trackName;
  final String layoutName;
  final String tyreLabel;

  const SessionWizardResult({
    required this.raceConfig,
    required this.trackName,
    required this.layoutName,
    required this.tyreLabel,
  });
}

class _MockTrack {
  final String name;
  final String continent;
  final List<String> layouts;
  const _MockTrack(this.name, this.continent, this.layouts);
}

/// Placeholder track catalog — not from the backend yet. Good enough to make the wizard
/// flow fully clickable/navigable; swapping this for a real `GET /tracks`-backed list is a
/// separate follow-up (the backend's `track`/`car` domains already have this data for the
/// panel, just not exposed to this app yet).
const _kTracks = [
  _MockTrack('Deep Forest Raceway', 'Europe', ['Full Circuit', 'Short']),
  _MockTrack('Nürburgring', 'Europe', ['GP', 'Nordschleife', 'Combined']),
  _MockTrack('Spa-Francorchamps', 'Europe', ['Full Circuit']),
  _MockTrack('Monza', 'Europe', ['Full Circuit', 'Junior']),
  _MockTrack('Silverstone', 'Europe', ['GP', 'International']),
  _MockTrack('Suzuka', 'Asia', ['Full Circuit', 'East']),
  _MockTrack('Fuji Speedway', 'Asia', ['Full Circuit', 'Short']),
  _MockTrack('Tokyo Expressway', 'Asia', ['South', 'Central Outer', 'Central Inner']),
  _MockTrack('Daytona', 'Americas', ['Road Course', 'Oval']),
  _MockTrack('Laguna Seca', 'Americas', ['Full Circuit']),
  _MockTrack('Interlagos', 'Americas', ['Full Circuit']),
  _MockTrack('Mount Panorama', 'Oceania', ['Full Circuit']),
];

const _kTyres = [
  ('S', 'Soft'),
  ('M', 'Medium'),
  ('H', 'Hard'),
  ('I', 'Inter'),
  ('W', 'Wet'),
];

enum _Step { continent, track, layout, sessionType, raceFormat, tyres }

/// Freeride pre-connect config: continent → track → layout → session type (+ race format
/// if it's a race) → tyres → start. Track/tyre choices are local/informational only for
/// now (GT7 itself dictates the real car/track/tyre once telemetry flows — this doesn't
/// change that), but session type/format feed directly into [RaceConfig], the same type
/// the fuel calculator uses, so completing this wizard also answers the fuel-calculator
/// config prompt that would otherwise show up once on the dashboard.
class SessionWizard extends StatefulWidget {
  final AppLang lang;

  const SessionWizard({super.key, required this.lang});

  @override
  State<SessionWizard> createState() => _SessionWizardState();
}

class _SessionWizardState extends State<SessionWizard> {
  final List<_Step> _history = [_Step.continent];
  _Step get _step => _history.last;

  String? _continent;
  _MockTrack? _track;
  String? _layout;
  RaceSessionType? _sessionType;
  RaceFormat? _raceFormat;
  final _minutesController = TextEditingController(text: '60');
  final _lapsController = TextEditingController(text: '30');
  String? _tyreCode;
  String _query = '';

  AppStrings get s => AppStrings(widget.lang);

  @override
  void dispose() {
    _minutesController.dispose();
    _lapsController.dispose();
    super.dispose();
  }

  void _push(_Step step) => setState(() => _history.add(step));
  void _pop() {
    if (_history.length > 1) setState(() => _history.removeLast());
  }

  void _finish() {
    final type = _sessionType!;
    final config = type == RaceSessionType.race
        ? RaceConfig(
            sessionType: type,
            format: _raceFormat,
            durationMinutes: _raceFormat == RaceFormat.time ? double.tryParse(_minutesController.text) : null,
            totalLaps: _raceFormat == RaceFormat.laps ? int.tryParse(_lapsController.text) : null,
          )
        : RaceConfig(sessionType: type);
    Navigator.of(context).pop(SessionWizardResult(
      raceConfig: config,
      trackName: _track?.name ?? '—',
      layoutName: _layout ?? '—',
      tyreLabel: _tyreCode ?? '—',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            Container(height: 2, color: AppColors.borderGray),
            Expanded(child: _buildStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _history.length > 1 ? _pop() : Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textWhite),
          ),
          Expanded(
            child: Text(
              s.wizardTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.continent:
        return _continentStep();
      case _Step.track:
        return _trackStep();
      case _Step.layout:
        return _layoutStep();
      case _Step.sessionType:
        return _sessionTypeStep();
      case _Step.raceFormat:
        return _raceFormatStep();
      case _Step.tyres:
        return _tyresStep();
    }
  }

  Widget _continentStep() {
    final continents = _kTracks.map((t) => t.continent).toSet().toList();
    return _OptionGrid(
      title: s.wizardContinent,
      options: continents,
      onTap: (c) {
        _continent = c;
        _push(_Step.track);
      },
    );
  }

  Widget _trackStep() {
    final tracks = _kTracks
        .where((t) => t.continent == _continent)
        .where((t) => _query.isEmpty || t.name.toUpperCase().contains(_query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(_continent ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _query.isEmpty ? s.searchHint : _query,
                  style: TextStyle(color: _query.isEmpty ? AppColors.textMuted : AppColors.accentYellow, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ),
              Text('${tracks.length} ${s.matches}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(child: Text(s.noEvents, style: const TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return SizedBox(
                      width: 220,
                      child: _OptionCard(
                        label: t.name,
                        note: '${t.layouts.length} layout${t.layouts.length > 1 ? 's' : ''}',
                        onTap: () {
                          _track = t;
                          _push(_Step.layout);
                        },
                      ),
                    );
                  },
                ),
        ),
        _buildLetterRow(),
      ],
    );
  }

  Widget _buildLetterRow() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderGray, width: 2))),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final ch in letters.split(''))
            _KeyButton(label: ch, onTap: () => setState(() => _query += ch)),
          _KeyButton(label: s.del, onTap: () => setState(() => _query = _query.isEmpty ? '' : _query.substring(0, _query.length - 1))),
          _KeyButton(label: s.clr, onTap: () => setState(() => _query = '')),
        ],
      ),
    );
  }

  Widget _layoutStep() {
    return _OptionGrid(
      title: '${_track?.name ?? ''} — ${s.wizardLayout}',
      options: _track?.layouts ?? const [],
      onTap: (l) {
        _layout = l;
        _push(_Step.sessionType);
      },
    );
  }

  Widget _sessionTypeStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _BigOption(
              label: s.training,
              onTap: () {
                _sessionType = RaceSessionType.training;
                _finish();
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BigOption(
              label: s.qualifying,
              onTap: () {
                _sessionType = RaceSessionType.qualifying;
                _finish();
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BigOption(
              label: s.race,
              onTap: () {
                _sessionType = RaceSessionType.race;
                _push(_Step.raceFormat);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _raceFormatStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.wizardRaceFormat, style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _BigOption(label: s.onTime, selected: _raceFormat == RaceFormat.time, onTap: () => setState(() => _raceFormat = RaceFormat.time)),
          const SizedBox(height: 10),
          _BigOption(label: s.onLaps, selected: _raceFormat == RaceFormat.laps, onTap: () => setState(() => _raceFormat = RaceFormat.laps)),
          if (_raceFormat == RaceFormat.time) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800),
              decoration: InputDecoration(labelText: s.raceDurationMinutes),
            ),
          ],
          if (_raceFormat == RaceFormat.laps) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _lapsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800),
              decoration: InputDecoration(labelText: s.lapCount),
            ),
          ],
          if (_raceFormat != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: () => _push(_Step.tyres), child: Text(s.wizardTyres)),
          ],
        ],
      ),
    );
  }

  Widget _tyresStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                for (final (code, label) in _kTyres) ...[
                  Expanded(
                    child: _TyreOption(
                      code: code,
                      label: label,
                      selected: _tyreCode == code,
                      onTap: () => setState(() => _tyreCode = code),
                    ),
                  ),
                  if (code != _kTyres.last.$1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderGray, width: 2))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_track?.name ?? ''} • ${_layout ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton(
                onPressed: _tyreCode == null ? null : _finish,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentYellow, foregroundColor: Colors.black, shape: const RoundedRectangleBorder()),
                child: Text(s.startSession),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final String title;
  final List<String> options;
  final ValueChanged<String> onTap;

  const _OptionGrid({required this.title, required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.4,
              children: options.map((o) => _BigOption(label: o, onTap: () => onTap(o))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BigOption({required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentYellow : AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: selected ? AppColors.accentYellow : AppColors.borderGray, width: 2)),
          child: Text(
            label,
            style: TextStyle(color: selected ? Colors.black : AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String note;
  final VoidCallback onTap;

  const _OptionCard({required this.label, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderGray, width: 2)),
          alignment: Alignment.bottomLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(note, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderGray)),
          child: Text(label, style: const TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _TyreOption extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TyreOption({required this.code, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentYellow : AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: selected ? AppColors.accentYellow : AppColors.borderGray, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(code, style: TextStyle(color: selected ? Colors.black : AppColors.textWhite, fontSize: 42, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: selected ? Colors.black : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
