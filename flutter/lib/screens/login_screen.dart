// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _workerCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _workerCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      final res  = await auth.login(
        _workerCtrl.text.trim().toUpperCase(),
        _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      context.push(
        AppRoutes.otp,
        extra: {'phone': _phoneCtrl.text.trim()},
      );
    } catch (e) {
      setState(() => _error = 'Login failed. Check your Worker ID and phone.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              AegisLogo(size: 52),
              const SizedBox(height: 24),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AegisColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to your Aegis account',
                style: TextStyle(fontSize: 15, color: AegisColors.textSecondary),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _workerCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Worker ID',
                        hintText: 'e.g. W001',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your Worker ID';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+91  ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 10) return 'Enter valid 10-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      ErrorBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AegisButton(
                      label: 'Send OTP',
                      loading: _loading,
                      onPressed: _submit,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AegisColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AegisColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AegisColors.textSecondary, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your Worker ID is given by your delivery platform or Aegis onboarding agent.',
                        style: TextStyle(fontSize: 12, color: AegisColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
