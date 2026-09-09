import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF012D1D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1B4332);
  static const Color onPrimaryContainer = Color(0xFF86AF99);
  
  static const Color secondary = Color(0xFF276C00);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF81FF45);
  static const Color onSecondaryContainer = Color(0xFF2A7300);

  static const Color tertiary = Color(0xFF3E1D00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF59320E);
  static const Color onTertiaryContainer = Color(0xFFD39A6E);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color background = Color(0xFFF8FAF9);
  static const Color onBackground = Color(0xFF191C1C);
  static const Color surface = Color(0xFFF8FAF9);
  static const Color onSurface = Color(0xFF191C1C);
  static const Color surfaceVariant = Color(0xFFE1E3E2);
  static const Color onSurfaceVariant = Color(0xFF414844);
  static const Color outline = Color(0xFF717973);
  static const Color outlineVariant = Color(0xFFC1C8C2);
  
  static const Color primaryFixed = Color(0xFFC1ECD4);
  static const Color primaryFixedDim = Color(0xFFA5D0B9);
  static const Color secondaryFixed = Color(0xFF81FF45);
  static const Color tertiaryFixed = Color(0xFFFFDCC3);
  static const Color onPrimaryFixed = Color(0xFF002114);
  static const Color onSecondaryFixed = Color(0xFF072100);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F3);
  static const Color surfaceContainer = Color(0xFFECEEED);
  static const Color surfaceContainerHigh = Color(0xFFE6E9E8);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E2);
  
  static const Color inversePrimary = Color(0xFFA5D0B9);
  
  static const double marginDesktop = 24.0;
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        background: background,
        onBackground: onBackground,
        surface: surface,
        onSurface: onSurface,
        surfaceVariant: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
      ),
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -0.02, color: onSurface),
        headlineLarge: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w600, color: onSurface),
        headlineMedium: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: onSurfaceVariant),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
        labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: onSurfaceVariant),
      ),      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryContainer,
          foregroundColor: primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceVariant, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: onSurfaceVariant),
      ),
    );
  }

  // Custom text styles
  static TextStyle get dataMono => GoogleFonts.jetBrainsMono(
      fontSize: 14, fontWeight: FontWeight.w500, color: onSurface);
      
  static TextStyle get displayLg => GoogleFonts.manrope(
      fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -0.02, color: onSurface);
      
  static TextStyle get headlineLg => GoogleFonts.manrope(
      fontSize: 32, fontWeight: FontWeight.w600, color: onSurface);
      
  static TextStyle get headlineLgMobile => GoogleFonts.manrope(
      fontSize: 24, fontWeight: FontWeight.w600, color: onSurface);
      
  static TextStyle get bodyMd => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w400, color: onSurface);
      
  static TextStyle get labelCaps => GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: onSurfaceVariant);
}
