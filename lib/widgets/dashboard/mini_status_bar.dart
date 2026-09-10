import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Minimal top-left status strip: PS5 icon + status dot, a thin separator, server icon +
/// status dot. No text labels, no driver name, no clock — just enough to answer "is
/// telemetry flowing" and "is the backend reachable" at a glance, without competing for
/// space with the dashboard itself.
///
/// Green dot = connected/receiving. Red = disconnected. The dot doesn't blink during
/// normal operation; only on disconnect does it get a subtle opacity pulse (handled by the
/// parent re-rendering with [online] toggling false, not by this widget animating itself).
class MiniStatusBar extends StatelessWidget {
  final bool ps5Online;
  final bool serverOnline;
  final double scale;

  const MiniStatusBar({super.key, required this.ps5Online, required this.serverOnline, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final iconSize = 20.0 * scale;
    final dotSize = 8.0 * scale;
    final gap = 8.0 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.videogame_asset_outlined, color: AppColors.textWhite, size: iconSize),
        SizedBox(width: gap * 0.6),
        _Dot(online: ps5Online, size: dotSize),
        SizedBox(width: gap),
        Container(width: 1, height: iconSize * 0.7, color: AppColors.borderGray),
        SizedBox(width: gap),
        Icon(Icons.storage_outlined, color: AppColors.textWhite, size: iconSize),
        SizedBox(width: gap * 0.6),
        _Dot(online: serverOnline, size: dotSize),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool online;
  final double size;

  const _Dot({required this.online, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.accentGreen : AppColors.accentRed,
      ),
    );
  }
}
