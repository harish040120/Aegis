// lib/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'utils/constants.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/register_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/home_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.initialized) return AppRoutes.splash;

      final onSplash = state.matchedLocation == AppRoutes.splash;
      final onAuth   = state.matchedLocation == AppRoutes.login ||
                       state.matchedLocation == AppRoutes.otp;
      final onReg    = state.matchedLocation == AppRoutes.register;
      final onPlan   = state.matchedLocation == AppRoutes.plan;

      if (!auth.isLoggedIn && !onAuth && !onSplash) return AppRoutes.login;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) {
          final extra = state.extra as Map<String, String>?;
          return OtpScreen(phone: extra?['phone'] ?? '');
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.plan,
        builder: (_, __) => const PlanScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
    ],
  );
}
