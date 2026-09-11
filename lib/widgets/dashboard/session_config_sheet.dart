import 'package:flutter/material.dart';

import '../../gt7/fuel_calculator.dart';
import '../../theme/app_colors.dart';

/// Two-step bottom sheet: pick session type (Trening/Kwalifikacje/Wyścig), and if it's a
/// race, pick its format (Na czas/Na okrążenia) plus the value. Training/qualifying finish
/// immediately on the first tap — there's nothing else to configure for them.
class SessionConfigSheet extends StatefulWidget {
  const SessionConfigSheet({super.key});

  /// Shows the sheet and returns the chosen config, or null if dismissed without one
  /// (including the caller's own auto-dismiss timer popping it with no result).
  static Future<RaceConfig?> show(BuildContext context) {
    return showModalBottomSheet<RaceConfig>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const SessionConfigSheet(),
    );
  }

  @override
  State<SessionConfigSheet> createState() => _SessionConfigSheetState();
}

class _SessionConfigSheetState extends State<SessionConfigSheet> {
  RaceSessionType? _type;
  RaceFormat? _format;
  final _minutesController = TextEditingController(text: '60');
  final _lapsController = TextEditingController(text: '30');

  @override
  void dispose() {
    _minutesController.dispose();
    _lapsController.dispose();
    super.dispose();
  }

  void _pickType(RaceSessionType type) {
    if (type == RaceSessionType.race) {
      setState(() => _type = type);
    } else {
      Navigator.of(context).pop(RaceConfig(sessionType: type));
    }
  }

  void _save() {
    final format = _format;
    if (format == null) return;
    final cfg = RaceConfig(
      sessionType: RaceSessionType.race,
      format: format,
      durationMinutes: format == RaceFormat.time ? double.tryParse(_minutesController.text) : null,
      totalLaps: format == RaceFormat.laps ? int.tryParse(_lapsController.text) : null,
    );
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _type == null ? _buildTypeStep() : _buildFormatStep(),
        ),
      ),
    );
  }

  List<Widget> _buildTypeStep() {
    return [
      const Text('Rodzaj sesji', style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      _OptionButton(label: 'Trening', onTap: () => _pickType(RaceSessionType.training)),
      const SizedBox(height: 8),
      _OptionButton(label: 'Kwalifikacje', onTap: () => _pickType(RaceSessionType.qualifying)),
      const SizedBox(height: 8),
      _OptionButton(label: 'Wyścig', onTap: () => _pickType(RaceSessionType.race)),
    ];
  }

  List<Widget> _buildFormatStep() {
    return [
      const Text('Format wyścigu', style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      _OptionButton(
        label: 'Na czas',
        selected: _format == RaceFormat.time,
        onTap: () => setState(() => _format = RaceFormat.time),
      ),
      const SizedBox(height: 8),
      _OptionButton(
        label: 'Na okrążenia',
        selected: _format == RaceFormat.laps,
        onTap: () => setState(() => _format = RaceFormat.laps),
      ),
      if (_format == RaceFormat.time) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _minutesController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(labelText: 'Czas wyścigu (minuty)'),
        ),
      ],
      if (_format == RaceFormat.laps) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _lapsController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(labelText: 'Liczba okrążeń'),
        ),
      ],
      if (_format != null) ...[
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    ];
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton({required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.accentYellow : AppColors.textWhite,
        side: BorderSide(color: selected ? AppColors.accentYellow : AppColors.borderGray),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label),
    );
  }
}
