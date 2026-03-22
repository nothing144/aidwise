import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors for Cyber-Humanitarian Dark Mode
  static const Color primary = Color(0xFF00E5FF); // Cyber Cyan
  static const Color secondary = Color(0xFFD500F9); // Neon Purple/Magenta
  
  static const Color background = Color(0xFF0A0A0A); // Obsidian Black
  static const Color surface = Color(0xFF1A1A1A); // Anthracite
  static const Color surfaceLow = Color(0xFF141414); // Slightly darker surface
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);

  // Urgency
  static const Color urgencyHigh = Color(0xFFFF1744); // Neon Red
  static const Color urgencyMedium = Color(0xFFFF9100); // Neon Orange
  static const Color urgencyLow = Color(0xFF00E676); // Neon Green
  static const Color success = Color(0xFF00E676); // Same as low urgency

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
          color: primary.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: 2,
        )
      ];
      
  static List<BoxShadow> get purpleGlow => [
        BoxShadow(
          color: secondary.withValues(alpha: 0.2),
          blurRadius: 24,
          spreadRadius: 1,
        )
      ];
      
  static List<BoxShadow> get glassmorphismShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ];
}
