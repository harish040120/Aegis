import '../models/models.dart';

/// Implements the exact premium formula from the README:
/// Weekly Premium = BASE × RiskMultiplier × LoyaltyFactor × ZoneFactor
///
/// BASE = weeklyEarningsAvg × 0.0075
/// RiskMultiplier = 1 + 0.4 × min(RiskScore / 8, 1)
/// LoyaltyFactor = 0.85 (no claims 12 weeks) → 1.0 (claims exist)
/// ZoneFactor = 0.95 (safe) → 1.10 (flood zone)

class RiskEngine {
  // ── Risk score weights (from README §4) ──────────────────────────────
  static const _weights = {
    'rainfall_65mm':    1.0,
    'temp_41c':         0.9,
    'aqi_300':          0.8,
    'order_drop_30pct': 1.0,
    'earnings_drop_20': 0.9,
  };

  // ── Zone factors ──────────────────────────────────────────────────────
  static const _zoneFactors = {
    'Zone 1 — North':   1.05,
    'Zone 2 — South':   1.00,
    'Zone 3 — East':    1.00,
    'Zone 4 — Central': 1.10,  // T. Nagar / flood zone
    'Zone 5 — West':    0.95,
  };

  // ── Compute everything ────────────────────────────────────────────────
  static RiskResult compute({
    required String zone,
    required double weeklyEarningsAvg,
    required double rainfallMm,   // last 3h
    required double tempC,
    required int aqi,
    required double orderDropPct, // 0-1
    required double earningsDropPct, // 0-1
    required bool hasClaimsLast12Weeks,
    required bool monsoonSeason,
  }) {
    // 1. Build active conditions map
    final conditions = <String, double>{};
    if (rainfallMm > 65)       conditions['rainfall_65mm']    = _weights['rainfall_65mm']!;
    if (tempC > 41)            conditions['temp_41c']          = _weights['temp_41c']!;
    if (aqi > 300)             conditions['aqi_300']           = _weights['aqi_300']!;
    if (orderDropPct > 0.30)   conditions['order_drop_30pct']  = _weights['order_drop_30pct']!;
    if (earningsDropPct > 0.20) conditions['earnings_drop_20'] = _weights['earnings_drop_20']!;

    // 2. RiskScore (sum of weights × 100/maxPossible)
    final rawScore = conditions.values.fold(0.0, (a, b) => a + b);
    final maxPossible = _weights.values.fold(0.0, (a, b) => a + b); // 4.6
    final riskScore = (rawScore / maxPossible * 100).round().clamp(0, 100);

    // 3. RiskMultiplier = 1 + 0.4 × min(RiskScore / 8, 1)
    // README uses score out of 8 where each condition contributes ~1.6 max
    // We normalise our 0-100 score to 0-8 scale
    final scoreOn8 = rawScore.clamp(0.0, 8.0);
    final riskMultiplier = 1.0 + 0.4 * (scoreOn8 / 8).clamp(0.0, 1.0);

    // 4. Loyalty factor
    final loyaltyFactor = hasClaimsLast12Weeks ? 1.0 : 0.85;

    // 5. Zone factor
    final zoneFactor = _zoneFactors[zone] ?? 1.0;

    // 6. Season factor (monsoon peak = extra multiplier)
    final seasonFactor = monsoonSeason ? 1.3 : 1.0;

    // 7. BASE = weeklyEarningsAvg × 0.75%
    final base = weeklyEarningsAvg * 0.0075;

    // 8. Final premium
    final weeklyPremium = (base * riskMultiplier * loyaltyFactor * zoneFactor * seasonFactor)
        .clamp(13.0, 100.0); // README caps at ₹100/week for most workers

    // 9. Daily coverage = payout from trigger (80% × daily avg earnings)
    final dailyEarnings = weeklyEarningsAvg / 6; // 6 working days
    final dailyCoverage = dailyEarnings * 0.80;
    final maxWeekly = dailyCoverage * 2;

    // 10. Band
    String band;
    if (riskScore < 25) {
      band = 'low';
    } else if (riskScore < 50)  band = 'medium';
    else if (riskScore < 75)  band = 'high';
    else                      band = 'extreme';

   // 11. Verification Logic
    // Logic: If Risk is High or Extreme, force manual verification (Photo/GPS)
    final bool needsVerification = (riskScore > 60); 

    return RiskResult(
  // 🚀 RECTIFIED: Mapping local variables to the required class parameters
  score: riskScore,
  band: band, 
  fraudLevel: "Low", // Defaulting for the factory; will be updated by AI real-time
  
  // 💰 DYNAMIC MATH: Using the calculated daily base
  dailyCoverage: double.parse(dailyCoverage.toStringAsFixed(0)),
  weeklyPremium: double.parse(weeklyPremium.toStringAsFixed(0)),
  
  // 🛰️ AUTONOMOUS FIELDS: Required for the Live Radar UI
  payoutTriggered: false, // Default state for the factory
  payoutAmount: 0.0,      // Will be populated by the AI response
  
  // 🛡️ SECURITY & BREAKDOWN
  requiresVerification: needsVerification, 
  breakdown: conditions,
);}

  // ── Payout calculation per trigger ───────────────────────────────────
  // README: Payout = (VerifiedHourlyRate × DisruptionHoursLost) × PayoutPct
  static double computePayout({
    required double weeklyEarningsAvg,
    required double disruptionHours,
    required double payoutPct, // e.g. 0.80
  }) {
    final hourlyRate = weeklyEarningsAvg / (6 * 10); // 6 days × 10 hrs
    return (hourlyRate * disruptionHours * payoutPct).roundToDouble();
  }

  // ── Dual-gate logic ───────────────────────────────────────────────────
  static bool evaluateGate1({
    required double rainfallMm,
    required double tempC,
    required int aqi,
    required double windKmh,
    required bool imdAlert,
    required bool cycloneAlert,
  }) {
    return rainfallMm > 65 ||
           (tempC > 41) ||
           aqi > 300 ||
           (windKmh > 60 && cycloneAlert) ||
           imdAlert;
  }

  static bool evaluateGate2({
    required double orderDropPct,  // 0-1
    required double earningsDropPct, // 0-1
    required bool workerOnlineDuringWindow,
  }) {
    return (orderDropPct > 0.30 || earningsDropPct > 0.20) &&
           workerOnlineDuringWindow;
  }
}
