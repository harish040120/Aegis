// ─────────────────────────────────────────────
// WORKER / AUTH
// ─────────────────────────────────────────────
class Worker {
  final String id;
  final String name;
  final String phone;
  final String platform;
  final String city;
  final String zone;
  final bool kycComplete;
  final bool subscribed;
  final String upiId;
  final double weeklyEarningsAvg;
  final int riskScore;
  final double weeklyPremium;
  final String planTier;
  final String? token;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.platform,
    required this.city,
    required this.zone,
    required this.kycComplete,
    required this.subscribed,
    required this.upiId,
    required this.weeklyEarningsAvg,
    required this.riskScore,
    required this.weeklyPremium,
    required this.planTier,
    this.token,
  });

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
    id: j['worker_id'] ?? j['id'] ?? '',
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    platform: j['platform'] ?? '',
    city: j['city'] ?? '',
    zone: j['zone'] ?? '',
    kycComplete: (j['kyc_status'] == 'VERIFIED') || (j['kycComplete'] == true),
    subscribed: (j['has_active_policy'] == true) || (j['subscribed'] == true),
    upiId: j['upi_id'] ?? '',
    weeklyEarningsAvg: (j['avg_earnings_12w'] ?? 0).toDouble(),
    riskScore: j['riskScore'] ?? 0,
    weeklyPremium: (j['weeklyPremium'] ?? 0).toDouble(),
    planTier: j['planTier'] ?? 'standard',
    token: j['token'],
  );
}

// ─────────────────────────────────────────────
// WEATHER
// ─────────────────────────────────────────────
class WeatherData {
  final double tempC;
  final double rainfallMm3h;
  final double windKmh;
  final int aqi;
  final String description;
  final String city;
  final DateTime fetchedAt;

  WeatherData({
    required this.tempC,
    required this.rainfallMm3h,
    required this.windKmh,
    required this.aqi,
    required this.description,
    required this.city,
    required this.fetchedAt,
  });
}

// ─────────────────────────────────────────────
// DISRUPTION ALERT
// ─────────────────────────────────────────────
enum TriggerType { heavyRainfall, severeFLooding, extremeHeat, cyclone, hazardousAqi, curfew, transportStrike, zoneSuspension }

class DisruptionAlert {
  final String id;
  final String type;
  final String typeLabel;
  final String severity;
  final double metric;
  final double threshold;
  final String zone;
  final String description;
  final DateTime detectedAt;

  DisruptionAlert({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.severity,
    required this.metric,
    required this.threshold,
    required this.zone,
    required this.description,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  factory DisruptionAlert.fromJson(Map<String, dynamic> j) {
    return DisruptionAlert(
      id: j['id']?.toString() ?? '',
      type: j['type'] ?? '',
      typeLabel: j['typeLabel'] ?? '',
      severity: j['severity'] ?? 'medium',
      metric: (j['metric'] ?? 0).toDouble(),
      threshold: (j['threshold'] ?? 0).toDouble(),
      zone: j['zone'] ?? 'Unknown Zone',
      description: j['description'] ?? 'Active AI disruption detected.',
      detectedAt: j['detectedAt'] != null 
          ? DateTime.parse(j['detectedAt']) 
          : DateTime.now(),
    );
  }
  
  // Check if alert has been active for at least 5 minutes
  bool get isActiveFor5Minutes {
    final duration = DateTime.now().difference(detectedAt);
    return duration.inMinutes >= 5;
  }
}

// ─────────────────────────────────────────────
// CLAIM
// ─────────────────────────────────────────────
enum ClaimStatus { pending, fraudCheck, approved, held, blocked, paid }

class Claim {
  final String id;
  final String workerId;
  final String alertId;
  final ClaimStatus status;
  final double amount;
  final double fraudScore;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String triggerType;
  final String zone;
  final String? reviewNote;

  Claim({
    required this.id,
    required this.workerId,
    required this.alertId,
    required this.status,
    required this.amount,
    required this.fraudScore,
    required this.createdAt,
    this.resolvedAt,
    required this.triggerType,
    required this.zone,
    this.reviewNote,
  });

  factory Claim.fromJson(Map<String, dynamic> j) => Claim(
    id: (j['id'] ?? j['payout_id'] ?? 0).toString(),
    workerId: j['worker_id']?.toString() ?? '',
    alertId: '',
    status: _mapPayoutStatus(j['payout_status']?.toString() ?? ''),
    amount: (j['amount'] ?? 0).toDouble(),
    fraudScore: (j['fraud_score'] ?? 0).toDouble(),
    createdAt: DateTime.tryParse(j['triggered_at']?.toString() ?? '') ?? DateTime.now(),
    resolvedAt: null,
    triggerType: j['trigger_type']?.toString() ?? 'Base Coverage',
    zone: j['zone']?.toString() ?? '',
    reviewNote: null,
  );

  static ClaimStatus _mapPayoutStatus(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': return ClaimStatus.approved;
      case 'PAID': return ClaimStatus.paid;
      case 'HELD': return ClaimStatus.held;
      case 'BANNED': return ClaimStatus.blocked;
      case 'DENIED': return ClaimStatus.blocked;
      default: return ClaimStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case ClaimStatus.pending: return 'Processing';
      case ClaimStatus.fraudCheck: return 'Under Review';
      case ClaimStatus.approved: return 'Approved';
      case ClaimStatus.held: return 'On Hold';
      case ClaimStatus.blocked: return 'Blocked';
      case ClaimStatus.paid: return 'Paid';
    }
  }
}

// ─────────────────────────────────────────────
// RISK RESULT (THE COMPILATION FIX)
// ─────────────────────────────────────────────
class RiskResult {
  final int score;
  final String band;
  final double multiplier;
  final double weeklyPremium; // 🚀 RESTORED
  final double dailyCoverage;
  final double maxWeekly;
  final Map<String, dynamic> breakdown;

  RiskResult({
    required this.score,
    required this.band,
    required this.multiplier,
    required this.weeklyPremium, // 🚀 RESTORED
    required this.dailyCoverage,
    required this.maxWeekly,
    required this.breakdown,
  });
}
