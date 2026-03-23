import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Super Admin Hub Color Palette
/// Slate/Dark theme with Emerald Green and Ruby Red accents
class AdminColors {
  // Primary Accent: Emerald Green
  static const Color emeraldGreen = Color(0xFF50C878);
  static const Color emeraldGreenLight = Color(0xFF7DD99B);
  static const Color emeraldGreenDark = Color(0xFF3BA55C);

  // Alert Accent: Ruby Red
  static const Color rubyRed = Color(0xFFE0115F);
  static const Color rubyRedLight = Color(0xFFFF4D8D);
  static const Color rubyRedDark = Color(0xFFB00D4A);

  // Slate/Dark Background Colors
  static const Color slateDarkest = Color(0xFF0D1117);
  static const Color slateDark = Color(0xFF161B22);
  static const Color slateMedium = Color(0xFF21262D);
  static const Color slateLight = Color(0xFF30363D);
  static const Color slateLighter = Color(0xFF484F58);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  // Border Colors
  static const Color borderDefault = Color(0xFF30363D);
  static const Color borderMuted = Color(0xFF21262D);

  // Status Colors
  static const Color statusSuccess = emeraldGreen;
  static const Color statusWarning = Color(0xFFD29922);
  static const Color statusError = rubyRed;
  static const Color statusInfo = Color(0xFF58A6FF);
}

/// Super Admin Hub Theme
ThemeData get adminDarkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AdminColors.emeraldGreen,
    onPrimary: AdminColors.slateDarkest,
    primaryContainer: AdminColors.emeraldGreenDark,
    onPrimaryContainer: AdminColors.textPrimary,
    secondary: AdminColors.textSecondary,
    onSecondary: AdminColors.slateDarkest,
    tertiary: AdminColors.rubyRed,
    onTertiary: AdminColors.textPrimary,
    error: AdminColors.rubyRed,
    onError: AdminColors.textPrimary,
    errorContainer: AdminColors.rubyRedDark,
    onErrorContainer: AdminColors.textPrimary,
    surface: AdminColors.slateDark,
    onSurface: AdminColors.textPrimary,
    surfaceContainerHighest: AdminColors.slateMedium,
    onSurfaceVariant: AdminColors.textSecondary,
    outline: AdminColors.borderDefault,
    shadow: Colors.black,
  ),
  scaffoldBackgroundColor: AdminColors.slateDarkest,
  appBarTheme: const AppBarTheme(
    backgroundColor: AdminColors.slateDark,
    foregroundColor: AdminColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AdminColors.slateMedium,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AdminColors.borderDefault, width: 1),
    ),
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: AdminColors.slateDark,
    surfaceTintColor: Colors.transparent,
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: AdminColors.slateDark,
    selectedIconTheme: const IconThemeData(color: AdminColors.emeraldGreen),
    unselectedIconTheme: const IconThemeData(color: AdminColors.textSecondary),
    selectedLabelTextStyle: GoogleFonts.inter(
      color: AdminColors.emeraldGreen,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelTextStyle: GoogleFonts.inter(
      color: AdminColors.textSecondary,
    ),
    indicatorColor: AdminColors.emeraldGreen.withValues(alpha: 0.15),
  ),
  dividerTheme: const DividerThemeData(
    color: AdminColors.borderDefault,
    thickness: 1,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AdminColors.slateMedium,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AdminColors.borderDefault),
    ),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: WidgetStateProperty.all(AdminColors.slateMedium),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AdminColors.borderDefault),
        ),
      ),
    ),
  ),
  textTheme: _buildAdminTextTheme(),
  iconTheme: const IconThemeData(color: AdminColors.textSecondary),
);

TextTheme _buildAdminTextTheme() => TextTheme(
  displayLarge: GoogleFonts.inter(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
  ),
  displayMedium: GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
  ),
  displaySmall: GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
  ),
  headlineLarge: GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  ),
  headlineMedium: GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  ),
  headlineSmall: GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  ),
  titleLarge: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  ),
  titleMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AdminColors.textPrimary,
  ),
  titleSmall: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AdminColors.textPrimary,
  ),
  labelLarge: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AdminColors.textPrimary,
  ),
  labelMedium: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AdminColors.textSecondary,
  ),
  labelSmall: GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AdminColors.textMuted,
  ),
  bodyLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
  ),
  bodyMedium: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AdminColors.textSecondary,
  ),
  bodySmall: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AdminColors.textMuted,
  ),
);
