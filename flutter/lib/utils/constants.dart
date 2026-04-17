// lib/utils/constants.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── API ────────────────────────────────────────────────────────────────────
class ApiConfig {
  static const String baseUrl = 'https://aegis-model-backend.onrender.com/api/v1';
  static const Duration timeout = Duration(seconds: 15);
}

// ─── Routes ─────────────────────────────────────────────────────────────────
class AppRoutes {
  static const String splash = '/';
  static const String start = '/start';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String registerStart = '/register-start';
  static const String register = '/register';
  static const String plan = '/plan';
  static const String home = '/home';
  static const String payoutSuccess = '/payout-success';
}

// ─── Registration Steps ──────────────────────────────────────────────────────
enum RegistrationStep { phone, otp, profile, income, location, done }

RegistrationStep registrationStepFromString(String? s) {
  switch (s?.toUpperCase()) {
    case 'PROFILE':
      return RegistrationStep.profile;
    case 'INCOME':
      return RegistrationStep.income;
    case 'LOCATION':
      return RegistrationStep.location;
    case 'DONE':
      return RegistrationStep.done;
    default:
      return RegistrationStep.profile;
  }
}

// ─── Plan Info ───────────────────────────────────────────────────────────────
class PlanInfo {
  final String name;
  final double weeklyPremium;
  final double payoutCap;
  final String tagline;
  final List<String> features;

  const PlanInfo({
    required this.name,
    required this.weeklyPremium,
    required this.payoutCap,
    required this.tagline,
    required this.features,
  });
}

const List<PlanInfo> kPlans = [
  PlanInfo(
    name: 'BASIC',
    weeklyPremium: 19,
    payoutCap: 240,
    tagline: 'Essential cover for light riders',
    features: [
      '₹240 weekly payout cap',
      'Rain + AQI triggers',
      'UPI instant transfer'
    ],
  ),
  PlanInfo(
    name: 'STANDARD',
    weeklyPremium: 34,
    payoutCap: 480,
    tagline: 'Best for full-time delivery workers',
    features: [
      '₹480 weekly payout cap',
      'All weather triggers',
      'UPI instant transfer',
      'Priority support'
    ],
  ),
  PlanInfo(
    name: 'PREMIUM',
    weeklyPremium: 59,
    payoutCap: 840,
    tagline: 'Maximum protection for top earners',
    features: [
      '₹840 weekly payout cap',
      'All triggers + income drop',
      'UPI instant transfer',
      'Dedicated support',
      'KYC fast-track'
    ],
  ),
];

// ─── Theme ───────────────────────────────────────────────────────────────────
class AegisColors {
  // Brand
  static const Color primary = Color(0xFF00C6A2); // teal
  static const Color primaryDark = Color(0xFF009E82);
  static const Color accent = Color(0xFFF5A623); // amber
  static const Color danger = Color(0xFFE84545);
  static const Color warning = Color(0xFFF5A623);
  static const Color success = Color(0xFF00C6A2);

  // Neutral dark surface
  static const Color bg = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color card = Color(0xFF1E2530);
  static const Color border = Color(0xFF2D3748);

  // Text
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // Risk levels
  static const Color riskLow = Color(0xFF00C6A2);
  static const Color riskMedium = Color(0xFFF5A623);
  static const Color riskHigh = Color(0xFFFF6B35);
  static const Color riskCritical = Color(0xFFE84545);
}

ThemeData buildAegisTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AegisColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AegisColors.primary,
      secondary: AegisColors.accent,
      surface: AegisColors.surface,
      error: AegisColors.danger,
    ),
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
      bodyColor: AegisColors.textPrimary,
      displayColor: AegisColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AegisColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AegisColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AegisColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AegisColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AegisColors.textSecondary),
      hintStyle: const TextStyle(color: AegisColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AegisColors.primary,
        foregroundColor: AegisColors.bg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    cardTheme: CardThemeData(
      color: AegisColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AegisColors.border),
      ),
      elevation: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AegisColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AegisColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AegisColors.textPrimary),
    ),
    dividerColor: AegisColors.border,
  );
}

// ─── Risk helpers ─────────────────────────────────────────────────────────────
Color riskColor(String level) {
  switch (level.toUpperCase()) {
    case 'LOW':
      return AegisColors.riskLow;
    case 'MEDIUM':
      return AegisColors.riskMedium;
    case 'HIGH':
      return AegisColors.riskHigh;
    case 'CRITICAL':
      return AegisColors.riskCritical;
    default:
      return AegisColors.textSecondary;
  }
}

IconData riskIcon(String level) {
  switch (level.toUpperCase()) {
    case 'LOW':
      return Icons.shield_outlined;
    case 'MEDIUM':
      return Icons.warning_amber_outlined;
    case 'HIGH':
      return Icons.warning_rounded;
    case 'CRITICAL':
      return Icons.crisis_alert_rounded;
    default:
      return Icons.help_outline;
  }
}
