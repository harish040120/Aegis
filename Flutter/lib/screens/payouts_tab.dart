import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class PayoutsTab extends StatefulWidget {
  const PayoutsTab({super.key});
  @override State<PayoutsTab> createState() => _PayoutsTabState();
}

class _PayoutsTabState extends State<PayoutsTab> with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch claims immediately without delay
      context.read<AegisProvider>().fetchClaims();
      context.read<AegisProvider>().fetchAlerts(immediate: true);
    });
  }

  @override void dispose() { _barCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final worker = prov.worker;
      final claims = prov.claims;
      final activeClaim = claims
          .where((c) => c.status == ClaimStatus.fraudCheck ||
                        c.status == ClaimStatus.pending)
          .firstOrNull;

      return RefreshIndicator(
        onRefresh: () async {
          await context.read<AegisProvider>().fetchClaims();
          await context.read<AegisProvider>().fetchAlerts(immediate: true);
        },
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHeader(context, worker, claims),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Manual refresh button
                ElevatedButton.icon(
                  onPressed: () async {
                    final prov = context.read<AegisProvider>();
                    await prov.fetchClaims();
                    await prov.fetchAlerts(immediate: true);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Payouts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (activeClaim != null) ...[
                  _buildFraudScoring(activeClaim),
                  const SizedBox(height: 12),
                  _buildPaymentPipeline(activeClaim),
                  const SizedBox(height: 12),
                ],
                _buildPayoutHistory(claims),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildHeader(BuildContext context, worker, List<Claim> claims) {
    final validClaims = claims.where((c) => c.amount > 0).toList();
    return Container(
    width: double.infinity,
    color: Colors.white,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      bottom: 14,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/main_logo.png', height: 28),
            Consumer<AegisProvider>(builder: (_, prov, __) => 
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Worker: ${prov.workerId ?? "N/A"}',
                  style: TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Payouts', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        Text('${validClaims.length} records found', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ),
  );
}

  Widget _heroStat(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.nunito(
      fontSize: 10, color: const Color(0xFF85B7EB))),
    const SizedBox(height: 2),
    Text(value, style: GoogleFonts.nunito(
      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
  ]);

  Widget _heroDivider() =>
    Container(width: 1, height: 36, color: const Color(0xFF1E3A6E));

  Widget _buildFraudScoring(Claim claim) {
    final score = claim.fraudScore;
    final isHeld = score >= 0.3 && score <= 0.7;
    final isBlocked = score > 0.7;

    return Column(children: [
      InfoBanner(
        title: isBlocked ? 'Claim blocked — manual review'
            : isHeld ? 'Claim under review'
            : 'AI fraud scoring in progress',
        message: isBlocked
            ? 'Multiple signals failed. Admin review started. You\'ll be notified within 4 hours.'
            : isHeld
                ? 'Score ${score.toStringAsFixed(2)} — held for secondary verification. Resolved within 4 hours.'
                : 'Validating your location data to ensure fair compensation.',
        bg: isBlocked ? AppColors.redLight
            : isHeld ? AppColors.amberLight : AppColors.blueLight,
        borderColor: isBlocked ? AppColors.redMid
            : isHeld ? AppColors.amberMid : AppColors.blueMid,
        titleColor: isBlocked ? AppColors.red
            : isHeld ? AppColors.amber : AppColors.blue,
        messageColor: isBlocked ? AppColors.red
            : isHeld ? AppColors.amber : AppColors.blue,
        icon: isBlocked ? Icons.block : isHeld ? Icons.hourglass_empty : Icons.security,
      ),
      const SizedBox(height: 12),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('AI fraud risk scoring'),
        const SizedBox(height: 12),
        ..._fraudSignals(score).map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(s['label']! as String, style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.mid)),
              AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) => Text(
                  '${((s['value']! as double) * _barAnim.value * 100).toInt()}%',
                  style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: s['color'] as Color)),
              ),
            ]),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (s['value']! as double) * _barAnim.value,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF1EFE8),
                  valueColor: AlwaysStoppedAnimation(s['color'] as Color))),
            ),
          ]),
        )),
      ])),
    ]);
  }

  List<Map<String, dynamic>> _fraudSignals(double fraudScore) {
    // Invert fraud score to show "legitimacy" percentages
    final legitimacy = 1.0 - fraudScore;
    return [
      {'label': 'Location consistency', 'value': (legitimacy * 0.95).clamp(0.0,1.0),
       'color': legitimacy > 0.7 ? AppColors.greenMid : AppColors.redMid},
      {'label': 'Movement patterns', 'value': (legitimacy * 0.90).clamp(0.0,1.0),
       'color': legitimacy > 0.7 ? AppColors.greenMid : AppColors.redMid},
      {'label': 'Order activity (90 min)', 'value': (legitimacy * 0.92).clamp(0.0,1.0),
       'color': legitimacy > 0.7 ? AppColors.greenMid : AppColors.redMid},
      {'label': 'Device data — mock GPS check', 'value': (legitimacy * 0.98).clamp(0.0,1.0),
       'color': legitimacy > 0.7 ? AppColors.greenMid : AppColors.redMid},
    ];
  }

  Widget _buildPaymentPipeline(Claim claim) {
    PipelineStepState s(ClaimStatus check) {
      final order = [ClaimStatus.pending, ClaimStatus.fraudCheck,
                     ClaimStatus.approved, ClaimStatus.paid];
      final ci = order.indexOf(claim.status);
      final si = order.indexOf(check);
      if (ci > si) return PipelineStepState.done;
      if (ci == si) return PipelineStepState.active;
      return PipelineStepState.pending;
    }

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Payment status'),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PipelineStep(label: 'Validated', state: s(ClaimStatus.pending)),
        PipelineStep(label: 'Fraud check', state: s(ClaimStatus.fraudCheck)),
        PipelineStep(label: 'Approved', state: s(ClaimStatus.approved)),
        PipelineStep(label: 'Paid', state: s(ClaimStatus.paid), isLast: true),
      ]),
      const SizedBox(height: 10),
      Center(child: Text(
        claim.status == ClaimStatus.paid
            ? '₹${claim.amount.toInt()} credited to your UPI'
            : claim.status == ClaimStatus.approved
                ? 'Processing UPI payout...'
                : 'Verifying claim — check back shortly',
        style: GoogleFonts.nunito(fontSize: 12,
          color: claim.status == ClaimStatus.paid
              ? AppColors.green : AppColors.blue,
          fontWeight: FontWeight.w600))),
    ]));
  }

  Widget _buildPayoutHistory(List<Claim> claims) {
    final validClaims = claims.where((c) => c.amount > 0).toList();
    
    if (validClaims.isEmpty) {
      return AppCard(
      child: Column(children: [
        const Icon(Icons.account_balance_wallet_outlined,
          color: AppColors.muted, size: 44),
        const SizedBox(height: 12),
        Text('No payouts yet', style: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 6),
        Text('Payouts will appear here when disruption events trigger a claim.',
          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted),
          textAlign: TextAlign.center),
      ]),
    );
    }

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const SectionTitle('Claim history'),
        Text('Total: ₹${validClaims.where((c) => c.status == ClaimStatus.paid).fold(0.0, (s,c)=>s+c.amount).toInt()}',
          style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
      ]),
      const SizedBox(height: 10),
      ...validClaims.map((c) {
        final isPaid = c.status == ClaimStatus.paid;
        final isHeld = c.status == ClaimStatus.held || c.status == ClaimStatus.fraudCheck;
        final isBlocked = c.status == ClaimStatus.blocked;

        return Column(children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: isPaid ? AppColors.greenLight
                    : isHeld ? AppColors.amberLight
                    : isBlocked ? AppColors.redLight : AppColors.blueLight,
                borderRadius: BorderRadius.circular(8)),
              child: Icon(
                isPaid ? Icons.check_circle_outline
                    : isBlocked ? Icons.block
                    : Icons.hourglass_empty,
                color: isPaid ? AppColors.green
                    : isHeld ? AppColors.amber
                    : isBlocked ? AppColors.red : AppColors.blue,
                size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.triggerType, style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              Text(DateFormat('MMM d, yyyy').format(c.createdAt),
                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
              if (c.reviewNote != null)
                Text(c.reviewNote!, style: GoogleFonts.nunito(
                  fontSize: 10, color: AppColors.amber,
                  fontStyle: FontStyle.italic)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(isPaid ? '+₹${c.amount.toInt()}' : '₹${c.amount.toInt()}',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: isPaid ? AppColors.green
                      : isHeld ? AppColors.amber
                      : isBlocked ? AppColors.red : AppColors.muted)),
              StatusBadge(
                label: c.statusLabel,
                bg: isPaid ? AppColors.greenLight
                    : isHeld ? AppColors.amberLight
                    : isBlocked ? AppColors.redLight : AppColors.blueLight,
                textColor: isPaid ? AppColors.green
                    : isHeld ? AppColors.amber
                    : isBlocked ? AppColors.red : AppColors.blue),
            ]),
          ]),
          if (c != claims.last)
            const Divider(height: 14, color: Color(0xFFF1EFE8)),
        ]);
      }),
    ]));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}
