import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'onboarding_screen.dart';
import 'plan_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _workerIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _showOtp = false;
  String? _demoOtp;
  String? _sessionId;
  String? _error;

  @override
  void dispose() {
    _workerIdCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _showOtp ? _otpStep() : _loginStep(),
                ),
              ),
            ],
          ),
          if (_loading)
            const LoadingOverlay(message: "Please wait..."),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/main_logo.png', height: 28),
          const SizedBox(height: 12),
          Text(_showOtp ? 'Verify OTP' : 'Welcome Back', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_showOtp ? 'Enter the code sent to your phone' : 'Sign in with your worker ID and phone', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _loginStep() {
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: _workerIdCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: "Worker ID (e.g., W001)",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: "Phone number",
                  prefixText: "+91 ",
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _workerIdCtrl.text.isNotEmpty && _phoneCtrl.text.length == 10
                ? _doLogin
                : null,
            child: const Text("Continue"),
          ),
        ),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              Text("OTP sent to +91 ${_phoneCtrl.text}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: _otpCtrl,
                maxLength: 6,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(counterText: ''),
              ),
              if (_demoOtp != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("Demo OTP: $_demoOtp", 
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _otpCtrl.text.length == 6 ? _doVerifyOtp : null,
            child: const Text("Verify & Login"),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() { _showOtp = false; _error = null; }),
          child: const Text("Change Worker ID"),
        ),
      ],
    );
  }

  Future<void> _doLogin() async {
    setState(() { _loading = true; _error = null; });
    
    try {
      final result = await context.read<AegisProvider>().login(
        _workerIdCtrl.text.trim().toUpperCase(),
        '+91${_phoneCtrl.text}',
      );
      
      setState(() {
        _sessionId = result['session_id'];
        _demoOtp = result['demo_otp'];
        _showOtp = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _doVerifyOtp() async {
    if (_sessionId == null) return;
    
    setState(() { _loading = true; _error = null; });
    
    try {
      final prov = context.read<AegisProvider>();
      await prov.verifyOtp(
        _workerIdCtrl.text.trim().toUpperCase(),
        _sessionId!,
        _otpCtrl.text,
      );
      
      final step = prov.registrationStep;
      
      if (!mounted) return;
      
      if (step == 'DONE') {
        if (prov.hasActivePlan) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
        }
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid OTP. Try entering: $_demoOtp';
        _loading = false;
      });
    }
  }
}