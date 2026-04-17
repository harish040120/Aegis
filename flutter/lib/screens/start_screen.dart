// lib/screens/start_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              AegisLogo(size: 52),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Aegis',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AegisColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to continue',
                style:
                    TextStyle(fontSize: 15, color: AegisColors.textSecondary),
              ),
              const SizedBox(height: 40),
              AegisButton(
                label: 'Login',
                onPressed: () => context.go(AppRoutes.login),
                icon: const Icon(Icons.login_rounded, size: 18),
              ),
              const SizedBox(height: 16),
              AegisButton(
                label: 'Register',
                onPressed: () => context.go(AppRoutes.registerStart),
                color: AegisColors.surface,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
