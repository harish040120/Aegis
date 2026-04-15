import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy       = Color(0xFF0C1A3A);
  static const navyLight  = Color(0xFF1E3A6E);
  static const blue       = Color(0xFF185FA5);
  static const blueLight  = Color(0xFFE6F1FB);
  static const blueMid    = Color(0xFF378ADD);
  static const green      = Color(0xFF27500A);
  static const greenLight = Color(0xFFEAF3DE);
  static const greenMid   = Color(0xFF639922);
  static const amber      = Color(0xFF854F0B);
  static const amberLight = Color(0xFFFAEEDA);
  static const amberMid   = Color(0xFFEF9F27);
  static const red        = Color(0xFFA32D2D);
  static const redLight   = Color(0xFFFCEBEB);
  static const redMid     = Color(0xFFE24B4A);
  static const bg         = Color(0xFFF4F5F8);
  static const white      = Color(0xFFFFFFFF);
  static const dark       = Color(0xFF2C2C2A);
  static const mid        = Color(0xFF5F5E5A);
  static const muted      = Color(0xFF888780);
  static const border     = Color(0xFFE8EAF0);
  static const divider    = Color(0xFFF1EFE8);

  static var primary;
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      secondary: AppColors.navy,
      surface: AppColors.white,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red, width: 1),
      ),
    ),
  );
}
