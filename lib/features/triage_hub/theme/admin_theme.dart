import 'package:flutter/material.dart';

class AdminColors {
  static const Color slateDarkest = Color(0xFF0F172A);
  static const Color slateDark = Color(0xFF1E293B);
  static const Color slateMedium = Color(0xFF334155);
  static const Color slateLight = Color(0xFF475569);

  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color rubyRed = Color(0xFFEF4444);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusInfo = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderDefault = Color(0xFF1E293B);
}

final adminDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AdminColors.slateDarkest,
  primaryColor: AdminColors.emeraldGreen,
  colorScheme: const ColorScheme.dark(
    primary: AdminColors.emeraldGreen,
    secondary: AdminColors.statusInfo,
    surface: AdminColors.slateDark,
    error: AdminColors.rubyRed,
  ),

  // FIX: withValues used instead of deprecated withOpacity
  dividerColor: AdminColors.slateMedium.withValues(alpha: 0.5),

  cardTheme: CardThemeData(
    color: AdminColors.slateDark,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AdminColors.borderDefault, width: 1),
    ),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AdminColors.slateDark,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AdminColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AdminColors.emeraldGreen,
      foregroundColor: AdminColors.slateDarkest,
      textStyle:
          const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AdminColors.textPrimary,
      side: const BorderSide(color: AdminColors.borderDefault),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          // FIX: withValues used here
          return AdminColors.emeraldGreen.withValues(alpha: 0.15);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminColors.emeraldGreen;
        }
        return AdminColors.textSecondary;
      }),
      side: WidgetStateProperty.all(
          const BorderSide(color: AdminColors.borderDefault)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  ),

  textTheme: const TextTheme(
    displayLarge:
        TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
    displayMedium:
        TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: AdminColors.textPrimary, fontSize: 16),
    bodyMedium: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
    labelSmall: TextStyle(
        color: AdminColors.textMuted, fontSize: 11, letterSpacing: 0.5),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AdminColors.slateDark,
    hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
    labelStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AdminColors.borderDefault),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AdminColors.borderDefault),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AdminColors.emeraldGreen, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);
