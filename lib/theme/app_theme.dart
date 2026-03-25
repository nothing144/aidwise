import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors for Aegis Zero (Stitch) Dark Mode
  static const Color primary = Color(0xFF00FFFF); // Electric Cyan
  static const Color secondary = Color(0xFFFF00FF); // Neon Magenta
  
  static const Color background = Color(0xFF131314); // Obsidian
  static const Color surface = Color(0xFF1C1B1C); // Surface Container Low
  static const Color surfaceLow = Color(0xFF0E0E0F); // Surface Container Lowest
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB9CAC9); // On Surface Variant

  // Urgency
  static const Color urgencyHigh = Color(0xFFFFB4AB); // Error light
  static const Color urgencyMedium = Color(0xFFFCE442); // Tertiary Fixed
  static const Color urgencyLow = Color(0xFF00FBFB); // Primary Container
  static const Color success = Color(0xFF00FBFB);

  // Aegis Zero Gradients
  static const LinearGradient cyanMagentaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00FFFF), Color(0xFFFF00FF)],
  );

  static const LinearGradient cyanMagentaGradientSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF003737), Color(0xFF380038)],
  );

  // Card Surface (slightly lifted from background)
  static const Color cardSurface = Color(0xFF2A2A2B); // Surface Container High
  static const Color outlineVariant = Color(0xFF3A4A49);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
            fontSize: 48, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -1.0),
        displayMedium: GoogleFonts.spaceGrotesk(
            fontSize: 36, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.spaceGrotesk(
            fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.spaceGrotesk(
            fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.spaceGrotesk(
            fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: textSecondary),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
    );
  }

  // Neon Glow Shadows
  static List<BoxShadow> get cyanGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.2), // primary glow
          blurRadius: 16,
          spreadRadius: 2,
        )
      ];
      
  static List<BoxShadow> get purpleGlow => [
        BoxShadow(
          color: secondary.withValues(alpha: 0.15),
          blurRadius: 20,
          spreadRadius: 1,
        )
      ];
      
  static List<BoxShadow> get glassmorphismShadow => [
        BoxShadow(
          color: const Color(0xFF00DDDD).withValues(alpha: 0.08), // Toned Cyan Ambient Shadow
          blurRadius: 40,
          offset: const Offset(0, 0),
        )
      ];

  // Aegis Zero Helpers
  static BoxDecoration get stitchCard => BoxDecoration(
    color: cardSurface.withValues(alpha: 0.6), // 60% opacity for glass effect
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: outlineVariant.withValues(alpha: 0.1), width: 1), // Ghostly 10% border
    boxShadow: glassmorphismShadow,
  );

  static BoxDecoration stitchCardWithLeftBorder(Color color) => BoxDecoration(
    color: cardSurface.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(12),
    border: Border(
      left: BorderSide(color: color, width: 3), 
      top: BorderSide(color: outlineVariant.withValues(alpha: 0.1)), 
      right: BorderSide(color: outlineVariant.withValues(alpha: 0.1)), 
      bottom: BorderSide(color: outlineVariant.withValues(alpha: 0.1))
    ),
    boxShadow: glassmorphismShadow,
  );
}
