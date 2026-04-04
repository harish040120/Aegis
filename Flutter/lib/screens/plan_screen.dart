import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  String _selectedTier = 'standard';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AegisProvider>().fetchWeatherAndScore();
    });
  }

  double _getPremiumForPlan(AegisProvider prov, String tier) {
    final base = prov.basePremium;
    switch (tier) {
      case 'basic':    return (base * 0.8).roundToDouble();
      case 'standard': return base.roundToDouble();
      case 'premium':  return (base * 1.2).roundToDouble();
      default:         return base.roundToDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final worker = prov.worker;

      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          Column(children: [
            _buildHeader(worker?.city ?? 'Chennai'),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Choose Protection Plan'),
                const SizedBox(height: 16),
                _buildPlanCard('basic', 'Basic Protection', _getPremiumForPlan(prov, 'basic'), '80% disruption coverage'),
                const SizedBox(height: 12),
                _buildPlanCard('standard', 'Standard Shield', _getPremiumForPlan(prov, 'standard'), '100% disruption coverage'),
                const SizedBox(height: 12),
                _buildPlanCard('premium', 'Premium Plus', _getPremiumForPlan(prov, 'premium'), '120% total coverage'),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubscribe,
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Text('Activate — ₹${_getPremiumForPlan(prov, _selectedTier).toInt()}/week'),
                  ),
                ),
              ]),
            )),
          ]),
          if (_isLoading) const LoadingOverlay(message: 'Activating policy...'),
        ]),
      );
    });
  }

  Widget _buildHeader(String city) => Container(
    width: double.infinity, color: Colors.white,
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
    child: Row(children: [
      Image.asset('assets/main_logo.png', height: 26),
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('DYNAMIC BASE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(city, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ]),
  );

  Widget _buildPlanCard(String id, String title, double price, String sub) {
    final isSel = _selectedTier == id;
    return InkWell(
      onTap: () => setState(() => _selectedTier = id),
      child: AppCard(
        borderColor: isSel ? AppColors.blue : AppColors.border,
        color: isSel ? AppColors.blueLight : Colors.white,
        child: Row(children: [
          Radio(value: id, groupValue: _selectedTier, onChanged: (v) => setState(() => _selectedTier = v!)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Text('₹${price.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
        ]),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);
    final prov = context.read<AegisProvider>();
    final premium = _getPremiumForPlan(prov, _selectedTier);
    
    try {
      final success = await prov.subscribe(planTier: _selectedTier, premium: premium);
      if (success && mounted) {
        // Navigation: Ensure we move to the main dashboard
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription failed. Please check your connection.')),
        );
      }
    } catch (e) {
      debugPrint("Subscribe Exception: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
