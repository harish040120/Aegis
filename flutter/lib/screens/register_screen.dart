// lib/screens/register_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late RegistrationStep _currentStep;
  bool _loading = false;
  String? _error;

  // Profile fields
  final _nameCtrl = TextEditingController();
  String _platform = 'ZOMATO';

  // Income fields
  final _earningsCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  // Location
  double? _lat;
  double? _lon;
  String? _detectedZone;
  bool _manualMode = false;
  String _manualCity = 'Chennai';
  String _manualZone = 'Chennai-Central';

  final List<String> _cities = ['Chennai', 'Bengaluru', 'Hyderabad', 'Mumbai'];
  final Map<String, List<String>> _zonesByCity = {
    'Chennai': [
      'Chennai-Central',
      'Chennai-North',
      'Chennai-South',
      'Chennai-East'
    ],
    'Bengaluru': ['BLR-Central', 'BLR-North', 'BLR-South'],
    'Hyderabad': ['HYD-Central', 'HYD-East', 'HYD-West'],
    'Mumbai': ['MUM-Central', 'MUM-North', 'MUM-South'],
  };

  final _platforms = ['ZOMATO', 'SWIGGY', 'DUNZO', 'ZEPTO', 'BLINKIT', 'OTHER'];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _currentStep = auth.resumedStep == RegistrationStep.done
        ? RegistrationStep.profile
        : auth.resumedStep;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _earningsCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  // ─── Step progress ─────────────────────────────────────────────────────────
  int get _stepIndex {
    switch (_currentStep) {
      case RegistrationStep.profile:
        return 0;
      case RegistrationStep.income:
        return 1;
      case RegistrationStep.location:
        return 2;
      default:
        return 0;
    }
  }

  // ─── Profile submit ────────────────────────────────────────────────────────
  Future<void> _submitProfile() async {
    if (_nameCtrl.text.trim().isEmpty || _upiCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final next = await auth.api.registerProfile(
        workerId: auth.workerId!,
        name: _nameCtrl.text.trim(),
        platform: _platform,
        upiId: _upiCtrl.text.trim(),
      );
      setState(() => _currentStep = registrationStepFromString(next));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Income submit ─────────────────────────────────────────────────────────
  Future<void> _submitIncome() async {
    final earningsStr = _earningsCtrl.text.trim();
    final upi = _upiCtrl.text.trim();
    if (earningsStr.isEmpty || upi.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    final earnings = double.tryParse(earningsStr);
    if (earnings == null || earnings <= 0) {
      setState(() => _error = 'Enter valid average weekly earnings.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final next = await auth.api.registerIncome(
        workerId: auth.workerId!,
        avgEarnings12w: earnings,
        targetDailyHours: 8,
        upiId: upi,
      );
      setState(() => _currentStep = registrationStepFromString(next));
    } catch (e) {
      setState(() => _error = 'Failed to save income data. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Location capture + submit ─────────────────────────────────────────────
  Future<void> _captureLocation() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.location.request();
        if (!status.isGranted) {
          setState(() {
            _error =
                'Location permission denied. Choose your city and zone manually.';
            _manualMode = true;
          });
          return;
        }
      } catch (_) {
        setState(() {
          _error = 'Location permissions are not available. Use manual entry.';
          _manualMode = true;
        });
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final auth = context.read<AuthProvider>();
      final zoneRes = await auth.api.detectZone(
        workerId: auth.workerId!,
        lat: pos.latitude,
        lon: pos.longitude,
      );
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _detectedZone = zoneRes.zone;
        _manualMode = false;
      });
    } catch (e) {
      setState(() => _error = 'Could not get location. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLocation() async {
    if (_lat == null || _lon == null) {
      if (!_manualMode) {
        setState(() => _error = 'Capture your location first.');
        return;
      }
      final fallback = _fallbackCoords(_manualCity);
      _lat = fallback.$1;
      _lon = fallback.$2;
      _detectedZone = _manualZone;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.api.registerLocation(
        workerId: auth.workerId!,
        lat: _lat!,
        lon: _lon!,
        zone: _detectedZone ?? 'Unknown',
      );
      if (mounted) context.go(AppRoutes.plan);
    } catch (e) {
      setState(() => _error = 'Failed to save location. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepper(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Profile', 'Income', 'Location'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AegisColors.border)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < _stepIndex
                    ? AegisColors.primary
                    : AegisColors.border,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < _stepIndex;
          final curr = idx == _stepIndex;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done || curr ? AegisColors.primary : AegisColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        done || curr ? AegisColors.primary : AegisColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 14, color: AegisColors.bg)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: curr
                                ? AegisColors.bg
                                : AegisColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[idx],
                style: TextStyle(
                  fontSize: 10,
                  color: curr ? AegisColors.primary : AegisColors.textSecondary,
                  fontWeight: curr ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case RegistrationStep.profile:
        return _buildProfileStep();
      case RegistrationStep.income:
        return _buildIncomeStep();
      case RegistrationStep.location:
        return _buildLocationStep();
      default:
        return _buildProfileStep();
    }
  }

  Widget _buildProfileStep() {
    return Column(
      key: const ValueKey('profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
            'Basic Details', 'Tell us your name, platform, and payout UPI ID.'),
        const SizedBox(height: 28),
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _platform,
          dropdownColor: AegisColors.card,
          decoration: const InputDecoration(
            labelText: 'Platform',
            prefixIcon: Icon(Icons.delivery_dining_outlined),
          ),
          items: _platforms
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _platform = v!),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _upiCtrl,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'rahul@okhdfcbank',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
        ),
        const SizedBox(height: 28),
        if (_error != null) ...[
          ErrorBanner(
              message: _error!, onDismiss: () => setState(() => _error = null)),
          const SizedBox(height: 16),
        ],
        AegisButton(
            label: 'Continue', loading: _loading, onPressed: _submitProfile),
      ],
    );
  }

  Widget _buildIncomeStep() {
    return Column(
      key: const ValueKey('income'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Income',
            'Use your average weekly earnings from your platform dashboard.'),
        const SizedBox(height: 28),
        TextFormField(
          controller: _earningsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
          decoration: const InputDecoration(
            labelText: 'Avg. Weekly Earnings',
            hintText: '₹ e.g. 1800',
            prefixIcon: Icon(Icons.currency_rupee),
            suffixText: 'INR/week',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Self-declared. The ML model refines this over time using your actual earnings.',
          style: TextStyle(fontSize: 12, color: AegisColors.textSecondary),
        ),
        const SizedBox(height: 20),
        const Text(
          'Use your average weekly earnings from your platform dashboard.',
          style: TextStyle(fontSize: 12, color: AegisColors.textSecondary),
        ),
        const SizedBox(height: 28),
        if (_error != null) ...[
          ErrorBanner(
              message: _error!, onDismiss: () => setState(() => _error = null)),
          const SizedBox(height: 16),
        ],
        AegisButton(
            label: 'Continue', loading: _loading, onPressed: _submitIncome),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      key: const ValueKey('location'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Home Location',
            'We use this as your base zone for weather trigger matching.'),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AegisColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _lat != null ? AegisColors.primary : AegisColors.border,
            ),
          ),
          child: _lat != null
              ? Column(
                  children: [
                    const Icon(Icons.my_location,
                        color: AegisColors.primary, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      'Location captured',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AegisColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_lat!.toStringAsFixed(4)}, ${_lon!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AegisColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: AegisColors.textMuted, size: 32),
                    const SizedBox(height: 10),
                    const Text(
                      'Location not yet captured',
                      style: TextStyle(color: AegisColors.textSecondary),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (_manualMode) ...[
          DropdownButtonFormField<String>(
            value: _manualCity,
            decoration: const InputDecoration(
              labelText: 'City',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: _cities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _manualCity = v;
                final zones = _zonesByCity[v] ?? [];
                if (zones.isNotEmpty) _manualZone = zones.first;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _manualZone,
            decoration: const InputDecoration(
              labelText: 'Zone',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: (_zonesByCity[_manualCity] ?? [])
                .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                .toList(),
            onChanged: (v) => setState(() => _manualZone = v ?? _manualZone),
          ),
          const SizedBox(height: 16),
          AegisButton(
            label: 'Use Manual Zone',
            onPressed: () {
              setState(() {
                _detectedZone = _manualZone;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        AegisButton(
          label: _lat != null ? 'Re-capture Location' : 'Capture My Location',
          loading: _loading && _lat == null,
          onPressed: _captureLocation,
          color: AegisColors.surface,
          icon: const Icon(Icons.gps_fixed, size: 18),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _manualMode = !_manualMode),
          child: Text(_manualMode ? 'Hide manual entry' : 'Enter manually'),
        ),
        const SizedBox(height: 28),
        if (_error != null) ...[
          ErrorBanner(
              message: _error!, onDismiss: () => setState(() => _error = null)),
          const SizedBox(height: 16),
        ],
        AegisButton(
          label: 'Finish Setup',
          loading: _loading && _lat != null,
          onPressed: (_lat != null || _manualMode) ? _submitLocation : null,
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 13, color: AegisColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Location is only used for zone-based weather matching.',
              style: TextStyle(fontSize: 11, color: AegisColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(sub,
            style: const TextStyle(
                fontSize: 14, color: AegisColors.textSecondary)),
      ],
    );
  }

  (double, double) _fallbackCoords(String city) {
    switch (city) {
      case 'Bengaluru':
        return (12.9716, 77.5946);
      case 'Hyderabad':
        return (17.3850, 78.4867);
      case 'Mumbai':
        return (19.0760, 72.8777);
      default:
        return (13.0827, 80.2707);
    }
  }
}
