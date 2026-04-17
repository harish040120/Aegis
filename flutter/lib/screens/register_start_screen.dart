// lib/screens/register_start_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class RegisterStartScreen extends StatefulWidget {
  const RegisterStartScreen({super.key});

  @override
  State<RegisterStartScreen> createState() => _RegisterStartScreenState();
}

class _RegisterStartScreenState extends State<RegisterStartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.login(null, _phoneCtrl.text.trim());

      if (!mounted) return;

      if (!res.isNewRegistration) {
        setState(() => _error = 'Already registered. Please login instead.');
        return;
      }

      context.push(
        AppRoutes.otp,
        extra: {'phone': _phoneCtrl.text.trim()},
      );
    } catch (e) {
      setState(() => _error = 'Registration failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Enter your phone number',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will send a verification OTP to continue registration.',
                style:
                    TextStyle(fontSize: 14, color: AegisColors.textSecondary),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                        if (v == null || v.trim().length < 10)
                          return 'Enter valid 10-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      ErrorBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AegisButton(
                      label: 'Continue',
                      loading: _loading,
                      onPressed: _submit,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
