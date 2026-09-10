import 'package:flutter/material.dart';

/// Central color palette for the Cheetah Live dashboard UI (lib/widgets/dashboard,
/// lib/layouts). Kept separate from the pairing/setup screen (hud_screen.dart), which
/// predates this dashboard redesign.
class AppColors {
  AppColors._();

  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF0C0C0C);
  static const Color borderGray = Color(0xFF303236);
  static const Color textMuted = Color(0xFF8B9098);
  static const Color textWhite = Color(0xFFF5F5F5);

  static const Color accentYellow = Color(0xFFFFD51E);
  static const Color accentOrange = Color(0xFFFF8C1A);
  static const Color accentRed = Color(0xFFFF1835);
  static const Color accentGreen = Color(0xFF00EF4D);
  static const Color accentPurple = Color(0xFFA62BFF);
  static const Color accentBlue = Color(0xFF2E9BFF);

  // Position-card rank colors (per explicit spec: 1st gold, 2nd bronze, 3rd silver).
  static const Color rankGold = Color(0xFFFFD700);
  static const Color rankBronze = Color(0xFFCD7F32);
  static const Color rankSilver = Color(0xFFC0C0C0);

  /// Unfilled/background track for the RPM arc and the vertical fuel bar — darker than
  /// [bgCard] so the colored fill reads clearly against it.
  static const Color trackDark = Color(0xFF25272B);
  static const Color fuelTrackDark = Color(0xFF17191C);
}
