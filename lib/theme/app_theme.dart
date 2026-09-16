import 'package:flutter/material.dart';

class AppTheme {
  static const teal = Color(0xFF0B6E63);
  static const tealDark = Color(0xFF083D38);
  static const cream = Color(0xFFF6F0E4);
  static const paper = Color(0xFFFFFBF4);
  static const gold = Color(0xFFD4A017);
  static const ink = Color(0xFF1C1917);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: gold,
      surface: paper,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      splashColor: teal.withValues(alpha: 0.16),
      highlightColor: teal.withValues(alpha: 0.08),
      hoverColor: teal.withValues(alpha: 0.10),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: tealDark,
        foregroundColor: paper,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: paper,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC9BBA8), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC9BBA8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
      ),
    );
  }
}
