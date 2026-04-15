// lib/screens/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _pinCtrl = TextEditingController();
  bool _loading  = false;
  String? _error;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String otp) async {
    if (otp.length < 6) return;
    setState(() { _loading = true; _error = null; });

    try {
      final auth     = context.read<AuthProvider>();
      final verified = await auth.verifyOtp(otp);

      if (!verified) {
        setState(() => _error = 'Incorrect OTP. Please try again.');
        return;
      }

      if (!mounted) return;

      if (auth.isNewRegistration) {
        context.go(AppRoutes.register);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PinTheme(
      width: 52,
      height: 58,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AegisColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AegisColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AegisColors.border),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AegisColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to +91 ${widget.phone}',
                style: const TextStyle(fontSize: 14, color: AegisColors.textSecondary),
              ),
              const SizedBox(height: 40),
              Pinput(
                controller: _pinCtrl,
                length: 6,
                defaultPinTheme: theme,
                focusedPinTheme: theme.copyWith(
                  decoration: theme.decoration!.copyWith(
                    border: Border.all(color: AegisColors.primary, width: 2),
                  ),
                ),
                errorPinTheme: theme.copyWith(
                  decoration: theme.decoration!.copyWith(
                    border: Border.all(color: AegisColors.danger, width: 2),
                  ),
                ),
                hapticFeedbackType: HapticFeedbackType.lightImpact,
                onCompleted: _loading ? null : _verify,
                enabled: !_loading,
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
                label: 'Verify OTP',
                loading: _loading,
                onPressed: () => _verify(_pinCtrl.text),
              ),
              const SizedBox(height: 20),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend OTP in ${_resendSeconds}s',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AegisColors.textSecondary,
                        ),
                      )
                    : TextButton(
                        onPressed: _startResendTimer,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(color: AegisColors.primary),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
