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
  int _step = 0;
  bool _loading = false;
  String? _demoOtp;

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  String _platform = 'Swiggy';
  
  // NEW: Initialized as empty to force detection
  String _city = ''; 
  String _zone = '';
  bool _locationDetected = false;

  final _platforms = ['Swiggy', 'Zomato', 'Amazon Flex', 'Zepto'];

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
                  child: [
                    _phoneStep,
                    _otpStep,
                    _profileStep,
                    _kycStep
                  ][_step](),
                ),
              ),
            ],
          ),
          if (_loading)
            const LoadingOverlay(message: "Processing..."),
        ],
      ),
    );
  }

  /// 🔷 HEADER
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
          Text(_titles[_step],
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_subs[_step],
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  final _titles = ["Enter your phone", "Verify OTP", "Complete profile", "Aadhaar KYC"];
  final _subs = ["Verification code", "Enter OTP", "Fill in details", "Identity verification"];

  /// 📱 PHONE STEP
  Widget _phoneStep() => Column(
        children: [
          AppCard(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(hintText: "Mobile number", prefixText: "+91 "),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _phoneCtrl.text.length == 10 ? _sendOtp : null,
            child: const Text("Send OTP"),
          ),
        ],
      );

  /// 🔐 OTP STEP
  Widget _otpStep() => Column(
        children: [
          AppCard(
            child: Column(
              children: [
                Text("OTP sent to +91 ${_phoneCtrl.text}", style: const TextStyle(color: Colors.grey)),
                TextField(
                  controller: _otpCtrl,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(counterText: ''),
                ),
                if (_demoOtp != null) ...[
                  const SizedBox(height: 10),
                  Text("Demo OTP: $_demoOtp", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _otpCtrl.text.length == 6 ? _verifyOtp : null,
            child: const Text("Verify"),
          ),
        ],
      );

  /// 👤 PROFILE STEP (UPDATED WITH GEOTRIGGER)
  Widget _profileStep() => Column(
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: "Full Name"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _upiCtrl,
                  decoration: const InputDecoration(hintText: "UPI ID"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 📍 AUTOMATED LOCATION CARD
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
          ElevatedButton(
            onPressed: _nameCtrl.text.isNotEmpty && _upiCtrl.text.isNotEmpty && _locationDetected
                ? _submitProfile
                : null,
            child: const Text("Continue"),
          ),
        ],
      );

  /// 🪪 KYC STEP
  Widget _kycStep() => Column(
        children: [
          AppCard(
            child: TextField(
              controller: _aadhaarCtrl,
              maxLength: 12,
              decoration: const InputDecoration(hintText: "Aadhaar Number"),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _aadhaarCtrl.text.length == 12 ? _submitKyc : null,
            child: const Text("Verify & Register"),
          ),
        ],
      );

  /// 🔧 ACTIONS
  Future<void> _detectLocation() async {
    setState(() => _loading = true);

    try {
      // Bypassing Geolocator to use system-defined zone mappings
      // Defaulting to 'Chennai-Central' for simulation stability
      const String detectedZone = 'Chennai-Central';
      const double lat = 13.0827;
      const double lon = 80.2707;

      final locationData = await context.read<AegisProvider>().getZoneFromGps(lat, lon);

      setState(() {
        _city = locationData['city'] ?? "Chennai";
        _zone = locationData['zone'] ?? detectedZone;
        _locationDetected = true;
      });

    } catch (e) {
      debugPrint("Simulation Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Simulation Error: Using fallback coordinates.")),
      );
    }

    setState(() => _loading = false);
  }
  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    final otp = await context.read<AegisProvider>().requestOtp('+91${_phoneCtrl.text}');
    setState(() { _demoOtp = otp; _step = 1; _loading = false; });
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    await context.read<AegisProvider>().verifyOtp('+91${_phoneCtrl.text}', _otpCtrl.text);
    final w = context.read<AegisProvider>().worker;
    if (w != null && w.kycComplete) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _step = 2);
    }
    setState(() => _loading = false);
  }

  Future<void> _submitProfile() async {
    setState(() => _loading = true);
    await context.read<AegisProvider>().register(
          name: _nameCtrl.text,
          phone: '+91${_phoneCtrl.text}',
          platform: _platform,
          city: _city,
          zone: _zone,
          upiId: _upiCtrl.text,
        );
    setState(() { _step = 3; _loading = false; });
  }

  Future<void> _submitKyc() async {
    setState(() => _loading = true);
    await context.read<AegisProvider>().completeKyc(_aadhaarCtrl.text);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
    setState(() => _loading = false);
  }
}