import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandPurple = Color(0xFF2D0B45);
  static const Color accentPink = Color(0xFFE94B9B);
  static const Color accentBlue = Color(0xFF3DC7F3);
  static const Color accentGold = Color(0xFFFFB23F);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: brandPurple,
        secondary: accentPink,
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F7FB),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
