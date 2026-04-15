import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'plan_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final prov = context.read<AegisProvider>();
    await Future.delayed(const Duration(milliseconds: 800));
    await prov.init();
    if (!mounted) return;
    
    if (prov.isLoggedIn) {
      final step = prov.registrationStep;
      if (step == 'DONE') {
        if (prov.hasActivePlan) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/plan');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo.png', height: 60),
              const SizedBox(height: 20),
              Text('AEGIS', style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.white, letterSpacing: 4)),
              const SizedBox(height: 8),
              Text('Parametric income protection', style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF85B7EB))),
              const SizedBox(height: 48),
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF85B7EB)))),
            ]),
          ),
        ),
      ),
    );
  }
}