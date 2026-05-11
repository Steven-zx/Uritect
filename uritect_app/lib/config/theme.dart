import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary
  static const Color primaryMain = Color(0xFF1D87A3);
  static const Color primaryDark = Color(0xFF146785);
  static const Color primaryLight = Color(0xFF41DAD8);
  static const Color primaryBlue = Color(0xFF2E6DB4);

  // Background
  static const Color bgMain = Color(0xFFF7FAFC);
  static const Color bgSoft = Color(0xFFEAF7F9);
  static const Color bgCard = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1F2D3D);
  static const Color textSecondary = Color(0xFF6B7C8F);

  // Border
  static const Color border = Color(0xFFE3EAF0);

  // Status
  static const Color statusLow = Color(0xFF2ECC71);
  static const Color statusModerate = Color(0xFFF39C12);
  static const Color statusHigh = Color(0xFFE74C3C);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryMain,
      secondary: AppColors.primaryLight,
      surface: AppColors.bgMain,
      error: AppColors.statusHigh,
    ),
    scaffoldBackgroundColor: AppColors.bgMain,
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
