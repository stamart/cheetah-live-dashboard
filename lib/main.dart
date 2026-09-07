import 'package:flutter/material.dart';

import 'ui/hud_screen.dart';

void main() {
  runApp(const CheetahLiveDashboardApp());
}

class CheetahLiveDashboardApp extends StatelessWidget {
  const CheetahLiveDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheetah Live',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5C518), brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.dark,
      home: const HudScreen(),
    );
  }
}
