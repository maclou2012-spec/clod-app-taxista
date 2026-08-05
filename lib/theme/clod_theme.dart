import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CLODColors {
  CLODColors._();

  static const Color azulCLOD = Color(0xFF1CA3E3);
  static const Color azulMarino = Color(0xFF1B3B7A);
  static const Color rojoUbicacion = Color(0xFFE63946);
  static const Color carbon = Color(0xFF2B2B2E);
  static const Color grisClaro = Color(0xFFF4F6F8);
}

class CLODTextStyles {
  CLODTextStyles._();

  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: CLODColors.grisClaro,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CLODColors.grisClaro,
      );

  static TextStyle get headingSmall => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CLODColors.grisClaro,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: CLODColors.grisClaro,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: CLODColors.grisClaro,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: CLODColors.grisClaro,
      );
}

class CLODTheme {
  CLODTheme._();

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CLODColors.azulCLOD,
      brightness: Brightness.dark,
      primary: CLODColors.azulCLOD,
      secondary: CLODColors.azulMarino,
      error: CLODColors.rojoUbicacion,
      surface: CLODColors.carbon,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CLODColors.carbon,
      appBarTheme: AppBarTheme(
        backgroundColor: CLODColors.carbon,
        foregroundColor: CLODColors.grisClaro,
        elevation: 0,
        titleTextStyle: CLODTextStyles.headingMedium,
      ),
      textTheme: TextTheme(
        headlineLarge: CLODTextStyles.headingLarge,
        headlineMedium: CLODTextStyles.headingMedium,
        headlineSmall: CLODTextStyles.headingSmall,
        bodyLarge: CLODTextStyles.bodyLarge,
        bodyMedium: CLODTextStyles.bodyMedium,
        bodySmall: CLODTextStyles.bodySmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CLODColors.azulCLOD,
          foregroundColor: CLODColors.grisClaro,
          textStyle: CLODTextStyles.bodyLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CLODColors.azulCLOD,
        foregroundColor: CLODColors.grisClaro,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CLODColors.azulMarino.withValues(alpha: 0.15),
        labelStyle: CLODTextStyles.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: CLODColors.azulMarino.withValues(alpha: 0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: CLODColors.grisClaro.withValues(alpha: 0.12),
    );
  }
}
