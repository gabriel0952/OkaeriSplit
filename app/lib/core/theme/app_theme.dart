import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Tasks 1.3/1.7: Indigo primary replacing generic purple
  static const _primaryColor = Color(0xFF4F46E5);
  static const _seedColor = _primaryColor;

  // Task 1.1: Light scaffold background (Apple #F5F5F7)
  static const _lightBackground = Color(0xFFF5F5F7);
  static const _lightCard = Color(0xFFFFFFFF);

  // Task 1.7: Dark equivalents
  static const _darkBackground = Color(0xFF1C1C1E);
  static const _darkCard = Color(0xFF2C2C2E);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: _lightBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Task 1.1: Scaffold background
      scaffoldBackgroundColor: _lightBackground,

      // Task 1.1: Card theme — white, no shadow, radius 16
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // Task 1.2: AppBar — transparent, zero elevation, tight title
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: _lightBackground,
        foregroundColor: Color(0xFF1D1D1F),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF1D1D1F),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: _lightCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Task 1.5: ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),

      // Task 1.5: FilledButton — 52px height, radius 14
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Task 1.5: Chip theme — no border, radius 20
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),

      // Task 1.5: Divider — subtle
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 0.5,
        space: 0.5,
      ),

      // Task 1.6: NavigationBar — white bg, lightweight indicator
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: _primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      // Task 1.4: Typography — tighter letter spacing
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            letterSpacing: -1.5, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            letterSpacing: -0.5, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(
            letterSpacing: -0.5, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            letterSpacing: -0.3, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            letterSpacing: -0.3, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            letterSpacing: -0.2, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(letterSpacing: -0.1),
        bodyMedium: TextStyle(letterSpacing: -0.1),
      ),

      // Cupertino overrides for iOS feel
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: _primaryColor,
      ),
    );
  }

  // Task 1.7: Dark theme — mirrors light but with dark palette
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: _darkBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,

      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: _darkBackground,
        foregroundColor: Color(0xFFF5F5F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F5F7),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: _darkCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 0.5,
        space: 0.5,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: _primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
            letterSpacing: -1.5, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            letterSpacing: -0.5, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(
            letterSpacing: -0.5, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            letterSpacing: -0.3, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            letterSpacing: -0.3, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            letterSpacing: -0.2, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(letterSpacing: -0.1),
        bodyMedium: TextStyle(letterSpacing: -0.1),
      ),

      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: _primaryColor,
        brightness: Brightness.dark,
        textTheme: CupertinoTextThemeData(),
      ),
    );
  }
}
