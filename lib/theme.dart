import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// L2LAAF Global Theme Configuration
/// This file defines the core brand identity for both Kaskflow and Moonlitely.

class L2LColors {
  // Brand Palette
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color deepSlate = Color(0xFF0F172A);
  static const Color rubyRed = Color(0xFFEF4444);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Neutral Tones (Dark Mode)
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
}

class L2LTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: L2LColors.deepSlate,
      primaryColor: L2LColors.emeraldGreen,

      colorScheme: const ColorScheme.dark(
        primary: L2LColors.emeraldGreen,
        secondary: L2LColors.infoBlue,
        surface: L2LColors.surfaceDark,
        error: L2LColors.rubyRed,
        onPrimary: Colors.white,
        onSurface: L2LColors.textPrimary,
      ),

      // Typography
      textTheme: GoogleFonts.nunitoSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: L2LColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: L2LColors.textPrimary,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: L2LColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),

      // Card Decoration
      // FIX: Changed CardTheme to CardThemeData to match parameter type
      cardTheme: CardThemeData(
        color: L2LColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: L2LColors.borderDark, width: 1),
        ),
      ),

      // Sidebar & Navigation Style
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: L2LColors.deepSlate,
        selectedIconTheme: const IconThemeData(color: L2LColors.emeraldGreen),
        unselectedIconTheme: IconThemeData(
            color: L2LColors.textSecondary.withValues(alpha: 0.5)),
        selectedLabelTextStyle: const TextStyle(
            color: L2LColors.emeraldGreen, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle:
            const TextStyle(color: L2LColors.textSecondary),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: L2LColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: L2LColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: L2LColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: L2LColors.emeraldGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: L2LColors.textSecondary),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: L2LColors.emeraldGreen,
          foregroundColor: L2LColors.deepSlate,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: L2LColors.textPrimary,
          side: const BorderSide(color: L2LColors.borderDark),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      dividerColor: L2LColors.borderDark.withValues(alpha: 0.5),

      // Tab Bar Style
      // FIX: Changed TabBarTheme to TabBarThemeData to match parameter type
      tabBarTheme: TabBarThemeData(
        labelColor: L2LColors.emeraldGreen,
        unselectedLabelColor: L2LColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: L2LColors.emeraldGreen, width: 2),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: L2LColors.emeraldGreen,
        foregroundColor: L2LColors.deepSlate,
      ),

      // Checkbox & Radio
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          // FIX: Enclosed in block for linting
          if (states.contains(WidgetState.selected)) {
            return L2LColors.emeraldGreen;
          }
          return L2LColors.surfaceDark;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Component Specifics
      chipTheme: ChipThemeData(
        backgroundColor: L2LColors.surfaceDark,
        labelStyle: const TextStyle(color: L2LColors.textPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: L2LColors.borderDark),
      ),

      highlightColor: L2LColors.emeraldGreen.withValues(alpha: 0.1),
      splashColor: L2LColors.emeraldGreen.withValues(alpha: 0.05),
    );
  }
}
