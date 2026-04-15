// lib/models/models.dart

// ─── Auth ─────────────────────────────────────────────────────────────────────
class LoginResponse {
  final String sessionToken;
  final String workerId;
  final bool isNewRegistration;
  final String? resumedStep;
  final String expiresAt;

  LoginResponse({
    required this.sessionToken,
    required this.workerId,
    required this.isNewRegistration,
    this.resumedStep,
    required this.expiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    sessionToken:      j['session_token'],
    workerId:          j['worker_id'],
    isNewRegistration: j['is_new_registration'] ?? true,
    resumedStep:       j['resumed_step'],
    expiresAt:         j['expires_at'] ?? '',
  );
}

// ─── Home ─────────────────────────────────────────────────────────────────────
class HomeData {
  final String workerId;
  final String name;
  final String zone;
  final String platform;
  final String planName;
  final double payoutCap;
  final String coverageEnd;
  final double riskScore;
  final String riskLevel;
  final double incomeDropPct;
  final String incomeSeverity;
  final String lastTriggerType;
  final double hoursOnline;
  final double earningsToday;
  final bool payoutTriggered;
  final String analysisPayoutStatus;
  final String lastAnalysisAt;
  final int unreadNotifications;

  HomeData({
    required this.workerId,
    required this.name,
    required this.zone,
    required this.platform,
    required this.planName,
    required this.payoutCap,
    required this.coverageEnd,
    required this.riskScore,
    required this.riskLevel,
    required this.incomeDropPct,
    required this.incomeSeverity,
    required this.lastTriggerType,
    required this.hoursOnline,
    required this.earningsToday,
    required this.payoutTriggered,
    required this.analysisPayoutStatus,
    required this.lastAnalysisAt,
    required this.unreadNotifications,
  });

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
    workerId:             j['worker_id'] ?? '',
    name:                 j['name'] ?? '',
    zone:                 j['zone'] ?? '',
    platform:             j['platform'] ?? '',
    planName:             j['plan_name'] ?? '',
    payoutCap:            (j['payout_cap'] ?? 0).toDouble(),
    coverageEnd:          j['coverage_end'] ?? '',
    riskScore:            (j['risk_score'] ?? 0).toDouble(),
    riskLevel:            j['risk_level'] ?? 'LOW',
    incomeDropPct:        (j['income_drop_pct'] ?? 0).toDouble(),
    incomeSeverity:       j['income_severity'] ?? '',
    lastTriggerType:      j['last_trigger_type'] ?? '',
    hoursOnline:          (j['hours_online'] ?? 0).toDouble(),
    earningsToday:        (j['earnings_today'] ?? 0).toDouble(),
    payoutTriggered:      j['payout_triggered'] ?? false,
    analysisPayoutStatus: j['analysis_payout_status'] ?? '',
    lastAnalysisAt:       j['last_analysis_at'] ?? '',
    unreadNotifications:  j['unread_notifications'] ?? 0,
  );
}

// ─── Analysis ─────────────────────────────────────────────────────────────────
class AnalysisResult {
  final String status;
  final String workerId;
  final double riskScore;
  final String riskLevel;
  final double incomeDrop;
  final String incomeSeverity;
  final double? payoutAmount;
  final String? triggerType;
  final int? payoutId;
  final double? newWeeklyPremium;

  AnalysisResult({
    required this.status,
    required this.workerId,
    required this.riskScore,
    required this.riskLevel,
    required this.incomeDrop,
    required this.incomeSeverity,
    this.payoutAmount,
    this.triggerType,
    this.payoutId,
    this.newWeeklyPremium,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final analytics = j['analytics'] ?? {};
    final risk = analytics['risk'] ?? {};
    final income = analytics['income'] ?? {};
    final payout = j['payout'];
    final premiumUpdate = j['premium_update'];

    return AnalysisResult(
      status:          j['status'] ?? '',
      workerId:        j['worker_id'] ?? '',
      riskScore:       (risk['score'] ?? 0).toDouble(),
      riskLevel:       risk['level'] ?? 'LOW',
      incomeDrop:      (income['drop'] ?? 0).toDouble(),
      incomeSeverity:  income['severity'] ?? '',
      payoutAmount:    payout != null ? (payout['amount'] ?? 0).toDouble() : null,
      triggerType:     payout?['trigger'],
      payoutId:        payout?['payout_id'],
      newWeeklyPremium: premiumUpdate != null
          ? (premiumUpdate['weekly_premium'] ?? 0).toDouble()
          : null,
    );
  }
}

// ─── Notification ─────────────────────────────────────────────────────────────
class AegisNotification {
  final int notifId;
  final String notificationType;
  final String title;
  final String body;
  final double? amount;
  final String? upiId;
  final String deliveryStatus;
  final String createdAt;

  AegisNotification({
    required this.notifId,
    required this.notificationType,
    required this.title,
    required this.body,
    this.amount,
    this.upiId,
    required this.deliveryStatus,
    required this.createdAt,
  });

  factory AegisNotification.fromJson(Map<String, dynamic> j) => AegisNotification(
    notifId:          j['notif_id'],
    notificationType: j['notification_type'] ?? '',
    title:            j['title'] ?? '',
    body:             j['body'] ?? '',
    amount:           j['amount'] != null ? (j['amount']).toDouble() : null,
    upiId:            j['upi_id'],
    deliveryStatus:   j['delivery_status'] ?? '',
    createdAt:        j['created_at'] ?? '',
  );
}

// ─── Alert ────────────────────────────────────────────────────────────────────
class WeatherAlert {
  final String type;
  final String typeLabel;
  final String severity;
  final double metric;
  final double threshold;
  final double triggerPct;
  final bool active;

  WeatherAlert({
    required this.type,
    required this.typeLabel,
    required this.severity,
    required this.metric,
    required this.threshold,
    required this.triggerPct,
    required this.active,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> j) => WeatherAlert(
    type:       j['type'] ?? '',
    typeLabel:  j['typeLabel'] ?? '',
    severity:   j['severity'] ?? '',
    metric:     (j['metric'] ?? 0).toDouble(),
    threshold:  (j['threshold'] ?? 0).toDouble(),
    triggerPct: (j['trigger_pct'] ?? 0).toDouble(),
    active:     j['active'] ?? false,
  );
}

// ─── Payout History ───────────────────────────────────────────────────────────
class PayoutRecord {
  final int payoutId;
  final double amount;
  final String triggerType;
  final double triggerPct;
  final String riskLevel;
  final String incomeSeverity;
  final String payoutStatus;
  final String triggeredAt;

  PayoutRecord({
    required this.payoutId,
    required this.amount,
    required this.triggerType,
    required this.triggerPct,
    required this.riskLevel,
    required this.incomeSeverity,
    required this.payoutStatus,
    required this.triggeredAt,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> j) => PayoutRecord(
    payoutId:      j['payout_id'],
    amount:        (j['amount'] ?? 0).toDouble(),
    triggerType:   j['trigger_type'] ?? '',
    triggerPct:    (j['trigger_pct'] ?? 0).toDouble(),
    riskLevel:     j['risk_level'] ?? '',
    incomeSeverity:j['income_severity'] ?? '',
    payoutStatus:  j['payout_status'] ?? '',
    triggeredAt:   j['triggered_at'] ?? '',
  );
}

// ─── Coverage ─────────────────────────────────────────────────────────────────
class CoverageData {
  final String planName;
  final double weeklyPremium;
  final double payoutCap;
  final String coverageStart;
  final String coverageEnd;
  final String kycStatus;
  final int policyId;

  CoverageData({
    required this.planName,
    required this.weeklyPremium,
    required this.payoutCap,
    required this.coverageStart,
    required this.coverageEnd,
    required this.kycStatus,
    required this.policyId,
  });

  factory CoverageData.fromJson(Map<String, dynamic> j) => CoverageData(
    planName:       j['plan_name'] ?? '',
    weeklyPremium:  (j['weekly_premium'] ?? 0).toDouble(),
    payoutCap:      (j['payout_cap'] ?? 0).toDouble(),
    coverageStart:  j['coverage_start'] ?? '',
    coverageEnd:    j['coverage_end'] ?? '',
    kycStatus:      j['kyc_status'] ?? 'PENDING',
    policyId:       j['policy_id'] ?? 0,
  );
}
