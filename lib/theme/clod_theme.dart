import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CLODColors {
  CLODColors._();

  // Colores de marca — fijos, no cambian entre temas.
  static const Color azulCLOD = Color(0xFF1CA3E3);
  static const Color azulMarino = Color(0xFF1B3B7A);
  static const Color rojoUbicacion = Color(0xFFE63946);
  static const Color carbon = Color(0xFF2B2B2E);
  static const Color grisClaro = Color(0xFFF4F6F8);

  // Tokens dependientes del tema activo. Usar estos (no `carbon`/
  // `grisClaro` directo) para texto/iconos y fondos de pantalla o tarjeta,
  // para que cada pantalla responda al modo claro/oscuro del usuario.
  static Color texto(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? grisClaro : carbon;

  static Color fondoTarjeta(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? azulMarino.withValues(alpha: 0.2)
      : Colors.white;

  static Color borde(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? grisClaro.withValues(alpha: 0.15)
      : const Color(0xFFD3D1C7);
}

class CLODTextStyles {
  CLODTextStyles._();

  // Sin color fijo aquí a propósito: cada uso hace `.copyWith(color:
  // CLODColors.texto(context))` (o hereda el color por defecto del tema
  // activo si no lo hace) para que el texto responda al modo claro/oscuro.
  static TextStyle get headingLarge =>
      GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600);

  static TextStyle get headingMedium =>
      GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600);

  static TextStyle get headingSmall =>
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400);
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
        titleTextStyle: CLODTextStyles.headingMedium.copyWith(
          color: CLODColors.grisClaro,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: CLODTextStyles.headingLarge.copyWith(
          color: CLODColors.grisClaro,
        ),
        headlineMedium: CLODTextStyles.headingMedium.copyWith(
          color: CLODColors.grisClaro,
        ),
        headlineSmall: CLODTextStyles.headingSmall.copyWith(
          color: CLODColors.grisClaro,
        ),
        bodyLarge: CLODTextStyles.bodyLarge.copyWith(
          color: CLODColors.grisClaro,
        ),
        bodyMedium: CLODTextStyles.bodyMedium.copyWith(
          color: CLODColors.grisClaro,
        ),
        bodySmall: CLODTextStyles.bodySmall.copyWith(
          color: CLODColors.grisClaro,
        ),
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
        labelStyle: CLODTextStyles.bodyMedium.copyWith(
          color: CLODColors.grisClaro,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: CLODColors.azulMarino.withValues(alpha: 0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: CLODColors.grisClaro.withValues(alpha: 0.12),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CLODColors.azulCLOD,
      brightness: Brightness.light,
      primary: CLODColors.azulCLOD,
      secondary: CLODColors.azulMarino,
      error: CLODColors.rojoUbicacion,
      surface: Colors.white,
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CLODColors.grisClaro,
      appBarTheme: AppBarTheme(
        backgroundColor: CLODColors.grisClaro,
        foregroundColor: CLODColors.carbon,
        elevation: 0,
        titleTextStyle: CLODTextStyles.headingMedium.copyWith(
          color: CLODColors.carbon,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: CLODTextStyles.headingLarge.copyWith(
          color: CLODColors.carbon,
        ),
        headlineMedium: CLODTextStyles.headingMedium.copyWith(
          color: CLODColors.carbon,
        ),
        headlineSmall: CLODTextStyles.headingSmall.copyWith(
          color: CLODColors.carbon,
        ),
        bodyLarge: CLODTextStyles.bodyLarge.copyWith(color: CLODColors.carbon),
        bodyMedium: CLODTextStyles.bodyMedium.copyWith(
          color: CLODColors.carbon,
        ),
        bodySmall: CLODTextStyles.bodySmall.copyWith(color: CLODColors.carbon),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CLODColors.azulCLOD,
          foregroundColor: Colors.white,
          textStyle: CLODTextStyles.bodyLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CLODColors.azulCLOD,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: CLODTextStyles.bodyMedium.copyWith(
          color: CLODColors.carbon,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: CLODColors.carbon.withValues(alpha: 0.12),
    );
  }
}
