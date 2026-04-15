import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class CoverageTab extends StatelessWidget {
  const CoverageTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final risk = prov.riskResult;

      return RefreshIndicator(
        onRefresh: prov.fetchWeatherAndScore,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHeader(context, prov),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (prov.hasActivePlan) _buildActiveCoverage(prov)
                else _buildNotSubscribed(context),
                const SizedBox(height: 12),
                if (risk != null) _buildRiskBreakdown(risk),
                const SizedBox(height: 12),
                _buildTriggerTable(),
                const SizedBox(height: 12),
                _buildPrivacyNote(),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildHeader(BuildContext context, AegisProvider prov) {
    return Container(
      width: double.infinity, color: Colors.white,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset('assets/main_logo.png', height: 28),
        const SizedBox(height: 12),
        const Text('Coverage Status', style: TextStyle(fontWeight: FontWeight.w600)),
        Text(prov.workerZone ?? 'Active Zone', style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _buildActiveCoverage(AegisProvider prov) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF639922), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${prov.activePlanName} Plan · Active', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.white)),
      ]),
      const SizedBox(height: 4),
      Text('Coverage valid until ${_formatDate(prov.coverageEnd)}', style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF85B7EB))),
      const Divider(color: Color(0xFF1E3A6E), height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _covStat('Weekly fee', '₹${prov.weeklyPremium?.toInt() ?? 0}'),
        _covStat('Risk Multiplier', '${prov.riskResult?.multiplier ?? 1.0}x'),
        _covStat('Daily base', '₹${prov.dynamicDailyBase.toInt()}'),
      ]),
    ]),
  );

  Widget _covStat(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.nunito(fontSize: 10, color: const Color(0xFF85B7EB))),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.white)),
  ]);

  Widget _buildNotSubscribed(BuildContext context) => AppCard(
    borderColor: AppColors.amberMid, color: AppColors.amberLight,
    child: Column(children: [
      const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 32),
      const SizedBox(height: 8),
      Text('No active coverage', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.amber)),
      const SizedBox(height: 4),
      Text('You are not protected against income disruptions.', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.amber), textAlign: TextAlign.center),
    ]),
  );

  Widget _buildRiskBreakdown(RiskResult risk) {
    final riskColors = {'low': AppColors.green, 'medium': AppColors.amber, 'high': AppColors.red, 'extreme': AppColors.red};
    final c = riskColors[risk.band.toLowerCase()] ?? AppColors.amber;

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const SectionTitle('Live Risk Assessment'),
        Text('Score ${risk.score}/100', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: risk.score / 100, minHeight: 10, backgroundColor: const Color(0xFFF1EFE8), valueColor: AlwaysStoppedAnimation(c))),
      const SizedBox(height: 12),
      Text('Current disruption risk is ${risk.band.toUpperCase()}.', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
    ]));
  }

  Widget _buildTriggerTable() {
    final List<Map<String, String>> triggers = [
      {'name': 'Heavy Rainfall', 'desc': '>45mm/hr + IMD alert', 'pay': '80%'},
      {'name': 'Severe Flooding', 'desc': '>70mm + flood zone', 'pay': '100%'},
      {'name': 'Extreme Heat', 'desc': '>36°C + activity drop', 'pay': '75%'},
      {'name': 'Hazardous AQI', 'desc': 'PM2.5 > 120 + order drop', 'pay': '80%'},
      {'name': 'Severe Income Loss', 'desc': 'ML model > 45% drop', 'pay': '100%'},
      {'name': 'Base Coverage', 'desc': 'Active worker (any day)', 'pay': '10%'},
    ];

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Parametric Trigger Table'),
      const SizedBox(height: 10),
      ...triggers.map((t) => Column(children: [
        Row(children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['name']!, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
            Text(t['desc']!, style: GoogleFonts.nunito(fontSize: 10, color: AppColors.muted)),
          ])),
          Text(t['pay']!, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
          const SizedBox(width: 10),
          const StatusBadge(label: 'Watching', bg: AppColors.blueLight, textColor: AppColors.blue),
        ]),
        if (t != triggers.last) const Divider(height: 12, color: Color(0xFFF1EFE8)),
      ])),
    ]));
  }

  Widget _buildPrivacyNote() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF1EFE8), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(child: Text('Location and sensor data is collected only during active disruption events to validate claims.', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.mid))),
    ]),
  );

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
