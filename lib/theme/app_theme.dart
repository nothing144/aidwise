import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primary = Color(0xFF2563EB); // Deep Blue
  static const Color primaryContainer = Color(0xFF004AC6); // Darker Blue for gradients
  static const Color secondary = Color(0xFF14B8A6); // Teal
  static const Color accent = Color(0xFF7C3AED); // Purple
  
  static const Color background = Color(0xFFF9FAFB); // Light Gray
  static const Color surface = Color(0xFFFFFFFF); // Cards White
  static const Color surfaceLow = Color(0xFFF3F4F5); // Low surface
  
  static const Color textPrimary = Color(0xFF191C1D);
  static const Color textSecondary = Color(0xFF434655);

  // Urgency
  static const Color urgencyHigh = Color(0xFFEF4444); // Red
  static const Color urgencyMedium = Color(0xFFF59E0B); // Orange
  static const Color urgencyLow = Color(0xFF22C55E); // Green

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
            fontSize: 48, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -1.0),
        displayMedium: GoogleFonts.manrope(
            fontSize: 36, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.manrope(
            fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.manrope(
            fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(
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
        ),
      ),
    );
  }

  // Soft ambient shadow
  static List<BoxShadow> get ambientShadow => [
        BoxShadow(
          color: primary.withOpacity(0.06),
          blurRadius: 32,
          offset: const Offset(0, 12),
        )
      ];
}
