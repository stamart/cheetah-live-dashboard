import 'package:flutter/material.dart';

/// Central color palette for the Cheetah Live dashboard UI (lib/widgets/dashboard,
/// lib/layouts, lib/screens/dashboard_screen.dart). Kept separate from the
/// pairing/setup screen (hud_screen.dart), which predates this dashboard redesign.
class AppColors {
  AppColors._();

  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF0C0C0C);
  static const Color borderGray = Color(0xFF2A2A2A);
  static const Color textMuted = Color(0xFF8A8A8A);
  static const Color textWhite = Color(0xFFF5F5F5);

  static const Color accentYellow = Color(0xFFF5C518);
  static const Color accentOrange = Color(0xFFFF8C1A);
  static const Color accentRed = Color(0xFFE8342A);
  static const Color accentGreen = Color(0xFF3ECF6E);
  static const Color accentPurple = Color(0xFFB565F5);
}
