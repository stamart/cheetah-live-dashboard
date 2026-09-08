import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'live_clock.dart';

/// Driver/PS5/server/wifi status readout shown in the dashboard top bar.
///
/// `compact: false` (landscape) — driver, PS5, dotted separator, server, wifi, clock, all
/// in one row. `compact: true` (portrait) — driver, PS5, server only; no wifi, no separator,
/// no clock (the portrait layout puts the clock next to the logo in its own row instead).
/// `scale` uniformly resizes everything (icons, text, gaps) — the top bar is meant to be a
/// small strip, not a hero element.
class ConnectionStatusRow extends StatelessWidget {
  final bool compact;
  final String driverName;
  final bool driverOnline;
  final String ps5Ip;
  final bool ps5Online;
  final bool serverOnline;
  final bool wifiConnected;
  final double scale;

  const ConnectionStatusRow({
    super.key,
    required this.compact,
    required this.driverName,
    required this.ps5Ip,
    this.driverOnline = true,
    this.ps5Online = true,
    this.serverOnline = true,
    this.wifiConnected = true,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final gapSm = 10.0 * scale;
    final gapMd = 14.0 * scale;

    final children = <Widget>[
      _DriverBlock(name: driverName, online: driverOnline, showDot: !compact, scale: scale),
      SizedBox(width: gapMd),
      _StatusBlock(icon: Icons.videogame_asset_outlined, label: 'PS5', online: ps5Online, value: ps5Ip, scale: scale),
    ];

    if (!compact) {
      children.addAll([
        SizedBox(width: gapSm),
        _DottedSeparator(scale: scale),
        SizedBox(width: gapSm),
      ]);
    } else {
      children.add(SizedBox(width: gapSm));
    }

    children.add(
      _StatusBlock(
        icon: Icons.storage_outlined,
        label: 'SERVER',
        online: serverOnline,
        value: serverOnline ? 'Online' : 'Offline',
        valueColor: serverOnline ? AppColors.accentGreen : AppColors.accentRed,
        scale: scale,
      ),
    );

    if (!compact) {
      children.addAll([
        SizedBox(width: gapMd),
        _WifiBlock(connected: wifiConnected, scale: scale),
        SizedBox(width: gapMd),
        LiveClock(fontSize: 9 * scale),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _DriverBlock extends StatelessWidget {
  final String name;
  final bool online;
  final bool showDot;
  final double scale;

  const _DriverBlock({required this.name, required this.online, required this.showDot, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, color: AppColors.textWhite, size: 9 * scale),
        SizedBox(width: 3 * scale),
        Text(name, style: TextStyle(color: AppColors.textWhite, fontSize: 7 * scale, fontWeight: FontWeight.w600)),
        if (showDot) ...[
          SizedBox(width: 3 * scale),
          _StatusDot(online: online, scale: scale),
        ],
      ],
    );
  }
}

class _StatusBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool online;
  final String value;
  final Color? valueColor;
  final double scale;

  const _StatusBlock({
    required this.icon,
    required this.label,
    required this.online,
    required this.value,
    required this.scale,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textWhite, size: 10 * scale),
        SizedBox(width: 3 * scale),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: AppColors.textWhite, fontSize: 6 * scale, fontWeight: FontWeight.w700)),
                SizedBox(width: 2.5 * scale),
                _StatusDot(online: online, scale: scale),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textMuted,
                fontSize: 6 * scale,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WifiBlock extends StatelessWidget {
  final bool connected;
  final double scale;

  const _WifiBlock({required this.connected, required this.scale});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.accentGreen : AppColors.accentRed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi, color: color, size: 10 * scale),
        SizedBox(width: 3 * scale),
        Text(
          connected ? 'CONNECTED' : 'DISCONNECTED',
          style: TextStyle(color: color, fontSize: 6 * scale, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool online;
  final double scale;

  const _StatusDot({required this.online, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.5 * scale,
      height: 3.5 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.accentGreen : AppColors.accentRed,
      ),
    );
  }
}

class _DottedSeparator extends StatelessWidget {
  final double scale;

  const _DottedSeparator({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.75 * scale),
          child: Container(
            width: 1.5 * scale,
            height: 1.5 * scale,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.borderGray),
          ),
        ),
      ),
    );
  }
}
