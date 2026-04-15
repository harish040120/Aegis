import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isAnalyzing = false;
  String? _errorMessage;
  bool _showAlertBanner = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AegisProvider>();
      prov.fetchAlerts(immediate: true);
      prov.startRealTimeEngine();
    });
  }
  
  void _startAlertTimer() {
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        setState(() {
          _showAlertBanner = false;
        });
      }
    });
  }

  Future<void> _runLiveAnalysis(AegisProvider prov) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      // Run analysis first - this creates payout in DB
      await prov.runAnalysis();
      
      // After analysis, check for alerts and trigger claims if needed
      await prov.fetchAlerts(immediate: true);
      
      // Fetch claims to show updated payout history
      await prov.fetchClaims();
    } catch (e) {
      setState(() {
        _errorMessage = "Analysis failed. Please check backend status.";
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final claims = prov.claims;

      return RefreshIndicator(
        onRefresh: () async {
          await prov.fetchWeatherAndScore();
          await prov.fetchAlerts();
          await prov.fetchClaims();
        },
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHeader(context, prov),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _buildLiveAnalysisCard(prov),
                const SizedBox(height: 16),
                _buildEarningsTiles(claims),
                const SizedBox(height: 12),
                _buildAlertPreview(context, prov),
                const SizedBox(height: 12),
                _buildClaimsCard(claims),
                const SizedBox(height: 12),
                if (prov.hasActivePlan)
                  _buildRenewButton(context, prov),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildLiveAnalysisCard(AegisProvider prov) {
    final live = prov.riskResult;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Live Risk & Fraud Analysis'),
              if (prov.lastResult != null)
                const StatusBadge(
                  label: 'Updated Just Now',
                  bg: AppColors.greenLight,
                  textColor: AppColors.green,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.nunito(color: AppColors.red, fontSize: 12),
              ),
            ),
          
          if (prov.lastResult != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF002B54), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _heroStat('RISK SCORE', '${live?.score ?? 0}'),
                      _heroDivider(),
                      _heroStat('FRAUD LVL', prov.lastResult?['analytics']?['fraud']?['level'] ?? 'SAFE'),
                      _heroDivider(),
                      _heroStat('DAILY BASE', '₹${prov.dynamicDailyBase.toInt()}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: prov.lastResult?['status'] == 'APPROVED' 
                          ? AppColors.green.withOpacity(0.2) 
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prov.lastResult?['status'] == 'APPROVED' 
                          ? 'AI DETECTED DISRUPTION: ₹${prov.lastResult?['payout']?['amount']} COVERAGE'
                          : 'STATUS: ${prov.lastResult?['status']}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Show alerts with manual trigger button
          if (_showAlertBanner) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.redMid),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('Active Alerts Detected!', style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold, color: AppColors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...prov.alerts.take(3).map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${a.typeLabel}', style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.redMid)),
                  )),
                  const SizedBox(height: 8),
                      Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            for (final alert in prov.alerts) {
                              await prov.triggerClaimAndPayout(alert.typeLabel);
                            }
                            setState(() {
                              _showAlertBanner = true;
                            });
                            _startAlertTimer();
                          },
                          icon: const Icon(Icons.flash_on, size: 18),
                          label: const Text('Trigger Payout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.blue),
                        onPressed: () async {
                          await prov.fetchClaims();
                        },
                        tooltip: 'Refresh payouts',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : () => _runLiveAnalysis(prov),
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Run System Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AegisProvider prov) {
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
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 26, 51, 126),
                  child: Text(
                    (prov.workerName?.isNotEmpty == true)
                        ? prov.workerName![0].toUpperCase()
                        : 'U',
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hello ${prov.workerName?.split(" ").first ?? ""}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          Row(
            children: [
              Text(
                prov.hasActivePlan ? "Plan Active" : "No plan",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ID: ${prov.workerId ?? "N/A"}',
                  style: const TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Column(children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 10, color: const Color(0xFF85B7EB))),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.white)),
      ]);

  Widget _heroDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFF1E3A6E));

  Widget _buildEarningsTiles(List<Claim> claims) {
    final totalPaid = claims
        .where((c) => c.status == ClaimStatus.paid)
        .fold(0.0, (s, c) => s + c.amount);
    final pending = claims
        .where((c) =>
            c.status == ClaimStatus.pending ||
            c.status == ClaimStatus.fraudCheck)
        .length;

    return Row(children: [
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total paid out',
              style: GoogleFonts.nunito(fontSize: 10, color: AppColors.green)),
          Text('₹${totalPaid.toInt()}',
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF173404))),
          Text('this month',
              style:
                  GoogleFonts.nunito(fontSize: 10, color: AppColors.greenMid)),
        ]),
      )),
      const SizedBox(width: 10),
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: pending > 0 ? AppColors.amberLight : AppColors.blueLight,
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pending claims',
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: pending > 0 ? AppColors.amber : AppColors.blue)),
          Text('$pending',
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: pending > 0
                      ? const Color(0xFF412402)
                      : const Color(0xFF042C53))),
          Text(pending > 0 ? 'under review' : 'all clear',
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color:
                      pending > 0 ? AppColors.amberMid : AppColors.blueMid)),
        ]),
      )),
    ]);
  }

  Widget _buildAlertPreview(BuildContext context, AegisProvider prov) {
    final active = prov.alerts;

    if (!_showAlertBanner && active.isEmpty && !prov.loadingAlerts) {
      return AppCard(
          child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.green, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No active disruptions',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
          Text('Your zone is clear right now',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
        ])),
        const StatusBadge(
            label: 'Safe',
            bg: AppColors.greenLight,
            textColor: AppColors.green),
      ]));
    }

    if (prov.loadingAlerts) {
      return AppCard(
        child: Row(children: [
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.blue))),
          const SizedBox(width: 12),
          Text('Checking your zone...',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.mid)),
        ]),
      );
    }

    final a = active.first;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 1))),
      child: AppCard(
        borderColor: AppColors.redMid,
        color: AppColors.redLight,
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: Color(0xFFF7C1C1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.red, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.typeLabel,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red)),
            Text('${a.zone} · Tap to view',
                style: GoogleFonts.nunito(
                    fontSize: 11, color: AppColors.redMid)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.red, size: 18),
        ]),
      ),
    );
  }

  Widget _buildClaimsCard(List<Claim> claims) {
    final validClaims = claims.where((c) => c.amount > 0).toList();
    
    if (validClaims.isEmpty) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Claim history'),
          const SizedBox(height: 10),
          Center(
              child: Column(children: [
            const Icon(Icons.history, color: AppColors.muted, size: 32),
            const SizedBox(height: 8),
            Text('No claims yet',
                style:
                    GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
            Text('Payouts will appear here after disruption events',
                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted),
                textAlign: TextAlign.center),
          ])),
        ]),
      );
    }

    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Recent claims'),
      const SizedBox(height: 8),
      ...validClaims.take(3).map((c) {
        final isPaid = c.status == ClaimStatus.paid;
        final isHeld =
            c.status == ClaimStatus.held || c.status == ClaimStatus.fraudCheck;
        return Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.triggerType,
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark)),
              Text(DateFormat('MMM d').format(c.createdAt),
                  style:
                      GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(isPaid ? '+₹${c.amount.toInt()}' : '₹${c.amount.toInt()}',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPaid
                          ? AppColors.green
                          : isHeld
                              ? AppColors.amber
                              : AppColors.muted)),
              StatusBadge(
                  label: c.statusLabel,
                  bg: isPaid
                      ? AppColors.greenLight
                      : isHeld
                          ? AppColors.amberLight
                          : AppColors.blueLight,
                  textColor: isPaid
                      ? AppColors.green
                      : isHeld
                          ? AppColors.amber
                          : AppColors.blue),
            ]),
          ]),
          if (c != validClaims.take(3).last)
            const Divider(height: 12, color: Color(0xFFF1EFE8)),
        ]);
      }),
    ]));
  }

  Widget _buildRenewButton(BuildContext context, AegisProvider prov) =>
      OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.blue, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Renew for next week',
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.blue)),
      );
}
