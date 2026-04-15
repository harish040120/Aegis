// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

// ─── Home Screen Shell ────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AegisLogo(size: 28),
            const SizedBox(width: 10),
            const Text('AEGIS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeDashboardTab(workerId: auth.workerId!),
          AlertsTab(workerId: auth.workerId!),
          CoverageTab(workerId: auth.workerId!),
          PayoutsTab(workerId: auth.workerId!),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AegisColors.surface,
        indicatorColor: AegisColors.primary.withOpacity(0.18),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AegisColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications, color: AegisColors.primary),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: AegisColors.primary),
            label: 'Coverage',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AegisColors.primary),
            label: 'Payouts',
          ),
        ],
      ),
    );
  }
}

// ─── HOME TAB ─────────────────────────────────────────────────────────────────
class HomeDashboardTab extends StatefulWidget {
  final String workerId;
  const HomeDashboardTab({super.key, required this.workerId});

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  HomeData? _data;
  bool _loadingHome  = true;
  bool _analyzing    = false;
  String? _error;
  AnalysisResult? _lastAnalysis;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _pingTimer = Timer.periodic(const Duration(minutes: 1), (_) => _ping());
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() { _loadingHome = true; _error = null; });
    try {
      final api  = context.read<AuthProvider>().api;
      final data = await api.getHome(widget.workerId);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = 'Could not load dashboard. Pull to refresh.');
    } finally {
      if (mounted) setState(() => _loadingHome = false);
    }
  }

  Future<void> _analyze() async {
    setState(() { _analyzing = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().api;
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
      } catch (_) {}

      final result = await api.analyze(
        workerId: widget.workerId,
        lat:      pos?.latitude  ?? _data?.riskScore ?? 13.0827,
        lon:      pos?.longitude ?? 80.2707,
      );
      setState(() => _lastAnalysis = result);
      await _loadHome();
    } catch (e) {
      setState(() => _error = 'Analysis failed. Please retry.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _ping() async {
    try {
      final api = context.read<AuthProvider>().api;
      Position? pos;
      try { pos = await Geolocator.getCurrentPosition(); } catch (_) {}
      await api.sessionPing(
        workerId: widget.workerId,
        lat: pos?.latitude  ?? 13.0827,
        lon: pos?.longitude ?? 80.2707,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHome) {
      return const Center(child: CircularProgressIndicator(color: AegisColors.primary));
    }

    return RefreshIndicator(
      color: AegisColors.primary,
      onRefresh: _loadHome,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Worker greeting ──
          if (_data != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_data!.name.split(' ').first} 👋',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_data!.platform}  ·  ${_data!.zone}',
                        style: const TextStyle(fontSize: 13, color: AegisColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                RiskBadge(level: _data!.riskLevel, score: _data!.riskScore),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Payout banner ──
          if (_data?.payoutTriggered == true || _lastAnalysis != null) ...[
            PayoutStatusBanner(
              status: _lastAnalysis?.status ?? _data?.analysisPayoutStatus ?? '',
              amount: _lastAnalysis?.payoutAmount ?? _data?.payoutCap,
            ),
            const SizedBox(height: 16),
          ],

          // ── Error ──
          if (_error != null) ...[
            ErrorBanner(message: _error!, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 16),
          ],

          // ── Stats grid ──
          if (_data != null) ...[
            const SectionHeader(title: 'TODAY\'S SNAPSHOT'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(
                  label: 'Earnings Today',
                  value: '₹${_data!.earningsToday.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee,
                  valueColor: AegisColors.primary,
                ),
                StatCard(
                  label: 'Hours Online',
                  value: '${_data!.hoursOnline.toStringAsFixed(1)}h',
                  icon: Icons.access_time_rounded,
                ),
                StatCard(
                  label: 'Income Drop',
                  value: '${_data!.incomeDropPct.toStringAsFixed(1)}%',
                  icon: Icons.trending_down_rounded,
                  valueColor: _data!.incomeDropPct > 50
                      ? AegisColors.danger
                      : AegisColors.warning,
                ),
                StatCard(
                  label: 'Payout Cap',
                  value: '₹${_data!.payoutCap.toStringAsFixed(0)}',
                  icon: Icons.shield_outlined,
                  valueColor: AegisColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Risk card ──
          if (_data != null) ...[
            const SectionHeader(title: 'RISK STATUS'),
            const SizedBox(height: 12),
            _RiskCard(data: _data!),
            const SizedBox(height: 20),
          ],

          // ── Analyse Now ──
          if (_lastAnalysis != null) ...[
            const SectionHeader(title: 'LAST ANALYSIS'),
            const SizedBox(height: 12),
            _AnalysisCard(result: _lastAnalysis!),
            const SizedBox(height: 16),
          ],

          AegisButton(
            label: _analyzing ? 'Analysing…' : 'Analyse Now',
            loading: _analyzing,
            onPressed: _analyze,
            icon: const Icon(Icons.analytics_outlined, size: 18),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Analysis also runs automatically every 60 seconds.',
              style: TextStyle(fontSize: 11, color: AegisColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final HomeData data;
  const _RiskCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = riskColor(data.riskLevel);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(riskIcon(data.riskLevel), color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Level: ${data.riskLevel}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15),
                    ),
                    Text(
                      'Score: ${data.riskScore.toStringAsFixed(1)} / 10',
                      style: const TextStyle(fontSize: 12, color: AegisColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: data.riskScore / 10,
              backgroundColor: AegisColors.border,
              color: color,
              minHeight: 6,
            ),
          ),
          if (data.lastTriggerType.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: AegisColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Trigger: ${data.lastTriggerType}',
                  style: const TextStyle(fontSize: 12, color: AegisColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final AnalysisResult result;
  const _AnalysisCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AegisColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AegisColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status', style: TextStyle(color: AegisColors.textSecondary, fontSize: 13)),
              StatusBadge(status: result.status),
            ],
          ),
          if (result.payoutAmount != null) ...[
            const Divider(height: 20, color: AegisColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payout', style: TextStyle(color: AegisColors.textSecondary, fontSize: 13)),
                Text(
                  '₹${result.payoutAmount!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AegisColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          if (result.triggerType != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trigger', style: TextStyle(color: AegisColors.textSecondary, fontSize: 13)),
                Text(result.triggerType!, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],
          if (result.newWeeklyPremium != null) ...[
            const Divider(height: 20, color: AegisColors.border),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: AegisColors.warning),
                const SizedBox(width: 6),
                Text(
                  'Premium updated to ₹${result.newWeeklyPremium!.toStringAsFixed(0)}/week',
                  style: const TextStyle(fontSize: 12, color: AegisColors.warning),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── ALERTS TAB ───────────────────────────────────────────────────────────────
class AlertsTab extends StatefulWidget {
  final String workerId;
  const AlertsTab({super.key, required this.workerId});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  List<WeatherAlert>? _alerts;
  List<AegisNotification>? _notifications;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final alerts = await api.getAlerts(widget.workerId);
      final notifs  = await api.getNotifications(widget.workerId);
      setState(() { _alerts = alerts; _notifications = notifs; });
    } catch (_) {
      setState(() { _alerts = []; _notifications = []; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AegisColors.primary));

    return RefreshIndicator(
      color: AegisColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if ((_notifications?.isNotEmpty ?? false)) ...[
            const SectionHeader(title: 'NOTIFICATIONS'),
            const SizedBox(height: 12),
            ..._notifications!.map((n) => _NotifCard(
              notif: n,
              onRead: () async {
                await context.read<AuthProvider>().api.markNotificationRead(n.notifId);
                _load();
              },
            )),
            const SizedBox(height: 20),
          ],
          const SectionHeader(title: 'ACTIVE WEATHER ALERTS'),
          const SizedBox(height: 12),
          if (_alerts?.isEmpty ?? true)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: AegisColors.primary, size: 40),
                    SizedBox(height: 12),
                    Text('No active alerts', style: TextStyle(color: AegisColors.textSecondary)),
                    Text(
                      'All clear in your zone.',
                      style: TextStyle(fontSize: 12, color: AegisColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._alerts!.map((a) => _AlertCard(alert: a)),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AegisNotification notif;
  final VoidCallback onRead;

  const _NotifCard({required this.notif, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AegisColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AegisColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AegisColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_outlined,
                color: AegisColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(notif.body,
                    style: const TextStyle(fontSize: 12, color: AegisColors.textSecondary)),
                if (notif.amount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '₹${notif.amount!.toStringAsFixed(0)} → ${notif.upiId ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AegisColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onRead,
            child: const Text('Mark read', style: TextStyle(fontSize: 11, color: AegisColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final WeatherAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = riskColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.typeLabel,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              StatusBadge(status: alert.severity),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricChip(label: 'Measured', value: alert.metric.toStringAsFixed(0)),
              const SizedBox(width: 8),
              _MetricChip(label: 'Threshold', value: alert.threshold.toStringAsFixed(0)),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Trigger',
                value: '${(alert.triggerPct * 100).toStringAsFixed(0)}%',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricChip({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AegisColors.primary.withOpacity(0.12)
            : AegisColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? AegisColors.primary.withOpacity(0.3) : AegisColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: highlight ? AegisColors.primary : AegisColors.textPrimary,
              )),
          Text(label, style: const TextStyle(fontSize: 9, color: AegisColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── COVERAGE TAB ─────────────────────────────────────────────────────────────
class CoverageTab extends StatefulWidget {
  final String workerId;
  const CoverageTab({super.key, required this.workerId});

  @override
  State<CoverageTab> createState() => _CoverageTabState();
}

class _CoverageTabState extends State<CoverageTab> {
  CoverageData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.getCoverage(widget.workerId);
      setState(() => _data = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AegisColors.primary));
    if (_data == null) {
      return const Center(child: Text('No active coverage.', style: TextStyle(color: AegisColors.textSecondary)));
    }

    return RefreshIndicator(
      color: AegisColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Plan badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AegisColors.primary.withOpacity(0.15),
                  AegisColors.primary.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AegisColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.shield_rounded, color: AegisColors.primary, size: 40),
                const SizedBox(height: 10),
                Text(
                  _data!.planName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AegisColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Policy #${_data!.policyId}',
                  style: const TextStyle(fontSize: 12, color: AegisColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _CoverageRow(label: 'Weekly Premium',    value: '₹${_data!.weeklyPremium.toStringAsFixed(0)}'),
          _CoverageRow(label: 'Payout Cap',        value: '₹${_data!.payoutCap.toStringAsFixed(0)}', highlight: true),
          _CoverageRow(label: 'Coverage Start',    value: _formatDate(_data!.coverageStart)),
          _CoverageRow(label: 'Coverage End',      value: _formatDate(_data!.coverageEnd)),
          _CoverageRow(label: 'KYC Status',        value: _data!.kycStatus),

          const SizedBox(height: 24),
          if (_data!.kycStatus == 'PENDING') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AegisColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AegisColors.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AegisColors.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Complete KYC (Aadhaar) to unlock faster claim processing.',
                      style: TextStyle(fontSize: 13, color: AegisColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AegisButton(
              label: 'Complete KYC',
              color: AegisColors.warning,
              onPressed: () => _showKycSheet(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showKycSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AegisColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KYC Verification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Only the last 4 digits are stored (hashed). Your full Aadhaar is never retained.',
              style: TextStyle(fontSize: 12, color: AegisColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Aadhaar Number',
                counterText: '',
                prefixIcon: Icon(Icons.fingerprint),
              ),
            ),
            const SizedBox(height: 20),
            AegisButton(
              label: 'Submit Aadhaar',
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                await auth.api.completeKyc(auth.workerId!, ctrl.text.trim());
                if (context.mounted) Navigator.pop(context);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _CoverageRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AegisColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AegisColors.textSecondary, fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: highlight ? AegisColors.primary : AegisColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAYOUTS TAB ──────────────────────────────────────────────────────────────
class PayoutsTab extends StatefulWidget {
  final String workerId;
  const PayoutsTab({super.key, required this.workerId});

  @override
  State<PayoutsTab> createState() => _PayoutsTabState();
}

class _PayoutsTabState extends State<PayoutsTab> {
  List<PayoutRecord>? _payouts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.getPayouts(widget.workerId);
      setState(() => _payouts = data);
    } catch (_) {
      setState(() => _payouts = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM, hh:mm a').format(dt.toLocal());
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AegisColors.primary));

    final total = _payouts?.fold<double>(0, (s, p) => s + (p.payoutStatus == 'PAID' ? p.amount : 0)) ?? 0;

    return RefreshIndicator(
      color: AegisColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AegisColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AegisColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Paid Out',
                          style: TextStyle(fontSize: 12, color: AegisColors.textSecondary)),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900, color: AegisColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_payouts?.length ?? 0}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const Text('Total Claims',
                        style: TextStyle(fontSize: 11, color: AegisColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'PAYOUT HISTORY'),
          const SizedBox(height: 12),

          if (_payouts?.isEmpty ?? true)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: AegisColors.textMuted, size: 40),
                    SizedBox(height: 12),
                    Text('No payouts yet', style: TextStyle(color: AegisColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ..._payouts!.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AegisColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AegisColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.triggerType,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      StatusBadge(status: p.payoutStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${p.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AegisColors.primary,
                        ),
                      ),
                      const Spacer(),
                      RiskBadge(level: p.riskLevel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(p.triggeredAt),
                    style: const TextStyle(fontSize: 11, color: AegisColors.textMuted),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
