import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'plan_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = false;
  String _currentStep = 'PROFILE';

  final _nameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _earningsCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  String _platform = 'ZOMATO';
  String _city = 'Chennai';
  String _zone = 'Chennai-Central';
  bool _locationDetected = false;

  final _platforms = ['ZOMATO', 'SWIGGY', 'BLINKIT', 'AMAZON'];

  @override
  void initState() {
    super.initState();
    final prov = context.read<AegisProvider>();
    _currentStep = prov.registrationStep ?? 'PROFILE';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _upiCtrl.dispose();
    _earningsCtrl.dispose();
    _hoursCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }

  @override
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
                  child: _buildCurrentStep(),
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
          Text(_stepTitles[_currentStep]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_stepSubs[_currentStep]!, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  final _stepTitles = {
    'PROFILE': 'Complete Your Profile',
    'INCOME': 'Income Details',
    'LOCATION': 'Location',
    'DONE': 'All Done!',
  };

  final _stepSubs = {
    'PROFILE': 'Tell us about yourself',
    'INCOME': 'Set your earnings baseline',
    'LOCATION': 'Where do you work?',
    'DONE': 'You are all set!',
  };

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 'PROFILE':
        return _profileStep();
      case 'INCOME':
        return _incomeStep();
      case 'LOCATION':
        return _locationStep();
      default:
        return _profileStep();
    }
  }

  Widget _profileStep() {
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: "Full Name"),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _platform,
                decoration: const InputDecoration(labelText: "Platform"),
                items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _platform = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _upiCtrl,
                decoration: const InputDecoration(hintText: "UPI ID (for payouts)"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nameCtrl.text.isNotEmpty && _upiCtrl.text.isNotEmpty
                ? _submitProfile
                : null,
            child: const Text("Continue"),
          ),
        ),
      ],
    );
  }

  Widget _incomeStep() {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Average Earnings",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your average daily earnings over the past 12 weeks",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _earningsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "Amount in INR",
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Target Daily Hours",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "Hours per day",
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _earningsCtrl.text.isNotEmpty && _hoursCtrl.text.isNotEmpty
                ? _submitIncome
                : null,
            child: const Text("Continue"),
          ),
        ),
      ],
    );
  }

  Widget _locationStep() {
    return Column(
      children: [
        AppCard(
          color: _locationDetected ? AppColors.greenLight : null,
          child: InkWell(
            onTap: _detectLocation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _locationDetected ? Icons.location_on : Icons.location_searching,
                    color: _locationDetected ? AppColors.green : AppColors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationDetected ? "Service Zone Verified" : "Detect My Zone",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _locationDetected ? AppColors.green : AppColors.blue,
                          ),
                        ),
                        Text(
                          _locationDetected ? "$_city • $_zone" : "Tap to sync with local risk parameters",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (_locationDetected) 
                    const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _locationDetected ? _submitLocation : null,
            child: const Text("Complete Registration"),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _skipLocation,
          child: const Text("Skip for now"),
        ),
      ],
    );
  }

  Future<void> _detectLocation() async {
    setState(() => _loading = true);
    try {
      final locationData = await context.read<AegisProvider>().getZoneFromGps(13.0827, 80.2707);
      setState(() {
        _city = locationData['city'] ?? 'Chennai';
        _zone = locationData['zone'] ?? 'Chennai-Central';
        _locationDetected = true;
      });
    } catch (e) {
      debugPrint("Location error: $e");
      setState(() {
        _city = 'Chennai';
        _zone = 'Chennai-Central';
        _locationDetected = true;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _submitProfile() async {
    setState(() => _loading = true);
    try {
      await context.read<AegisProvider>().registerProfile(
        name: _nameCtrl.text,
        platform: _platform,
      );
      setState(() => _currentStep = 'INCOME');
    } catch (e) {
      debugPrint("Profile error: $e");
    }
    setState(() => _loading = false);
  }

  Future<void> _submitIncome() async {
    setState(() => _loading = true);
    try {
      await context.read<AegisProvider>().registerIncome(
        avgEarnings12w: double.tryParse(_earningsCtrl.text) ?? 1800,
        targetDailyHours: double.tryParse(_hoursCtrl.text) ?? 8,
      );
      setState(() => _currentStep = 'LOCATION');
    } catch (e) {
      debugPrint("Income error: $e");
    }
    setState(() => _loading = false);
  }

  Future<void> _submitLocation() async {
    setState(() => _loading = true);
    try {
      await context.read<AegisProvider>().registerLocation(
        city: _city,
        zone: _zone,
      );
      
      final prov = context.read<AegisProvider>();
      if (prov.hasActivePlan) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
    setState(() => _loading = false);
  }

  Future<void> _skipLocation() async {
    setState(() => _loading = true);
    try {
      await context.read<AegisProvider>().registerLocation(
        city: 'Chennai',
        zone: 'Chennai-Central',
      );
      
      final prov = context.read<AegisProvider>();
      if (prov.hasActivePlan) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
      }
    } catch (e) {
      debugPrint("Skip error: $e");
    }
    setState(() => _loading = false);
  }
}