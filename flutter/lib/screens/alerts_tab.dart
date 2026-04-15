import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});
  @override State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch alerts immediately when tab is opened (no 5-minute filter)
      context.read<AegisProvider>().fetchAlerts(immediate: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final activeAlerts = prov.alerts;

        return RefreshIndicator(
        onRefresh: () => prov.fetchAlerts(immediate: true),
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: prov.loadingAlerts
                ? const Center(child: CircularProgressIndicator())
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('Active Disruption Alerts'),
                    const SizedBox(height: 12),
                    if (activeAlerts.isEmpty)
                      _buildEmptyState()
                    else
                      ...activeAlerts.map((a) => _buildAlertCard(context, prov, a)),
                  ]),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() => Center(
        child: Column(children: [
          const SizedBox(height: 40),
          Icon(Icons.shield_outlined, size: 64, color: AppColors.green.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('Your zone is safe', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
          Text('No parametric triggers active.', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
        ]),
      );

  Widget _buildAlertCard(BuildContext context, AegisProvider prov, DisruptionAlert alert) {
    return AppCard(
      borderColor: AppColors.redMid,
      color: AppColors.redLight,
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(alert.typeLabel, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.red)),
              Text('Severity threshold crossed in ${alert.zone}', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.redMid)),
            ])),
          ]),
          const SizedBox(height: 12),
          // Claim is auto-submitted - show status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 16),
                const SizedBox(width: 6),
                Text('Claim auto-submitted', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
