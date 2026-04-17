// lib/screens/plan_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _selected = 1; // default: STANDARD
  bool _loading = false;
  String? _error;
  bool _loadingTiers = true;
  String? _pricingError;
  List<PricingTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final auth = context.read<AuthProvider>();
      final pricing = await auth.api.getPricingTiers(workerId: auth.workerId);
      setState(() {
        _tiers = pricing.tiers;
        _loadingTiers = false;
        final recIndex = _tiers.indexWhere((t) => t.rec == true);
        if (recIndex >= 0) _selected = recIndex;
      });
    } catch (_) {
      setState(() {
        _pricingError = 'Could not load pricing tiers.';
        _loadingTiers = false;
      });
    }
  }

  Future<void> _subscribe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final plan = _tiers.isNotEmpty ? _tiers[_selected] : kPlans[_selected];
      final planName =
          plan is PricingTier ? plan.name : (plan as PlanInfo).name;
      final weeklyPremium = plan is PricingTier
          ? plan.premium.toDouble()
          : (plan as PlanInfo).weeklyPremium;
      await auth.api.subscribe(
        workerId: auth.workerId!,
        planName: planName,
        weeklyPremium: weeklyPremium,
        paymentRef: 'demo_payment_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Subscription failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Plan'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your protection starts the moment you subscribe.',
                      style: TextStyle(
                          fontSize: 15, color: AegisColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    if (_loadingTiers)
                      const Center(
                          child: CircularProgressIndicator(
                              color: AegisColors.primary))
                    else if (_pricingError != null)
                      Text(_pricingError!,
                          style: const TextStyle(color: AegisColors.danger))
                    else if (_tiers.isNotEmpty)
                      ...List.generate(
                          _tiers.length,
                          (i) => _PricingCard(
                                tier: _tiers[i],
                                selected: _selected == i,
                                onTap: () => setState(() => _selected = i),
                              ))
                    else
                      ...List.generate(
                          kPlans.length,
                          (i) => _PlanCard(
                                plan: kPlans[i],
                                selected: _selected == i,
                                onTap: () => setState(() => _selected = i),
                              )),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      ErrorBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AegisColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AegisColors.textSecondary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'KYC (Aadhaar) is optional at this stage. You can complete it later from Settings.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AegisColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selected Plan',
                          style: TextStyle(color: AegisColors.textSecondary)),
                      Text(
                        kPlans[_selected].name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AegisColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weekly Premium',
                          style: TextStyle(color: AegisColors.textSecondary)),
                      Text(
                        '₹${kPlans[_selected].weeklyPremium.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AegisButton(
                    label: 'Activate Coverage →',
                    loading: _loading,
                    onPressed: _subscribe,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard(
      {required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AegisColors.primary.withOpacity(0.08)
              : AegisColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AegisColors.primary : AegisColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AegisColors.primary
                              : AegisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.tagline,
                        style: const TextStyle(
                            fontSize: 12, color: AegisColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${plan.weeklyPremium.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      '/week',
                      style: TextStyle(
                          fontSize: 11, color: AegisColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AegisColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Up to ₹${plan.payoutCap.toStringAsFixed(0)} / week payout',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AegisColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: AegisColors.primary),
                      const SizedBox(width: 8),
                      Text(f,
                          style: const TextStyle(
                              fontSize: 13, color: AegisColors.textSecondary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final PricingTier tier;
  final bool selected;
  final VoidCallback onTap;

  const _PricingCard(
      {required this.tier, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AegisColors.primary.withOpacity(0.08)
              : AegisColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AegisColors.primary : AegisColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AegisColors.primary
                              : AegisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tier.rec ? 'Recommended' : 'Coverage Tier',
                        style: const TextStyle(
                            fontSize: 12, color: AegisColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${tier.premium}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      '/week',
                      style: TextStyle(
                          fontSize: 11, color: AegisColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Weekly payout cap: ₹${tier.cap}',
              style: const TextStyle(
                  fontSize: 12, color: AegisColors.textSecondary),
            )
          ],
        ),
      ),
    );
  }
}
