import 'package:flutter/material.dart';

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
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryMain,
      secondary: AppColors.primaryLight,
      surface: AppColors.bgMain,
      error: AppColors.statusHigh,
    ),
    scaffoldBackgroundColor: AppColors.bgMain,
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryMain,
        side: const BorderSide(color: AppColors.primaryMain, width: 1.5),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryMain),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
