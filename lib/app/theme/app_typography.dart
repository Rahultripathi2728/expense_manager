import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system using Plus Jakarta Sans.
/// Modern fintech styling: Bold/tight headings, readable bodies.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
    // Display
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.3,
    ),

    // Headlines
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),

    // Titles
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    // Body
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),

    // Labels
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
    ),
  );
}
