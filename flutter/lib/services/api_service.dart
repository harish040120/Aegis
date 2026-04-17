// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String? token;

  ApiService({this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res =
        await http.get(uri, headers: _headers).timeout(ApiConfig.timeout);
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body);
      } catch (_) {}
      throw ApiException(
        body['detail'] ?? body['message'] ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<LoginResponse> login(String? workerId, String phone) async {
    final body = {
      'phone': phone,
    };
    if (workerId != null && workerId.isNotEmpty) {
      body['worker_id'] = workerId;
    }
    final data = await _post('/login', body);
    return LoginResponse.fromJson(data);
  }

  Future<bool> verifyOtp(
      String workerId, String sessionToken, String otp) async {
    final data = await _post('/verify-otp', {
      'worker_id': workerId,
      'session_token': sessionToken,
      'otp_code': otp,
    });

    return data['status'] == 'AUTHENTICATED';
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  Future<String> registerProfile({
    required String workerId,
    required String name,
    required String platform,
    required String upiId,
  }) async {
    final data = await _post('/register/profile', {
      'worker_id': workerId,
      'name': name,
      'platform': platform,
      'upi_id': upiId,
    });
    return data['next_step'] ?? data['registration_step'] ?? 'INCOME';
  }

  Future<String> registerIncome({
    required String workerId,
    required double avgEarnings12w,
    required double targetDailyHours,
    required String upiId,
  }) async {
    final data = await _post('/register/income', {
      'worker_id': workerId,
      'avg_earnings_12w': avgEarnings12w,
      'target_daily_hours': targetDailyHours,
      'upi_id': upiId,
    });
    return data['next_step'] ?? data['registration_step'] ?? 'LOCATION';
  }

  Future<String> registerLocation({
    required String workerId,
    required double lat,
    required double lon,
    required String zone,
  }) async {
    final data = await _post('/register/location', {
      'worker_id': workerId,
      'lat': lat,
      'lon': lon,
      'zone': zone,
    });
    return data['registration_step'];
  }

  Future<void> completeKyc(String workerId, String aadhaarNumber) async {
    await _post('/complete-kyc', {
      'worker_id': workerId,
      'aadhaar_number': aadhaarNumber,
    });
  }

  // ─── Plan ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> subscribe({
    required String workerId,
    required String planName,
    required double weeklyPremium,
    required String paymentRef,
  }) async {
    return await _post('/subscribe', {
      'worker_id': workerId,
      'plan_name': planName,
      'weekly_premium': weeklyPremium,
      'payment_ref': paymentRef,
    });
  }

  // ─── Home ──────────────────────────────────────────────────────────────────

  Future<HomeData> getHome(String workerId) async {
    final data = await _get('/home?worker_id=$workerId');
    return HomeData.fromJson(data);
  }

  Future<AnalysisResult> analyze({
    required String workerId,
    required double lat,
    required double lon,
  }) async {
    final data = await _post('/analyze', {
      'worker_id': workerId,
      'lat': lat,
      'lon': lon,
    });
    return AnalysisResult.fromJson(data);
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<List<AegisNotification>> getNotifications(String workerId) async {
    final data = await _get('/notifications?worker_id=$workerId');
    final list = data['notifications'] as List;
    return list.map((e) => AegisNotification.fromJson(e)).toList();
  }

  Future<void> markNotificationRead(int notifId) async {
    await _post('/notifications/read', {'notif_id': notifId});
  }

  // ─── Alerts ────────────────────────────────────────────────────────────────

  Future<List<WeatherAlert>> getAlerts(String workerId) async {
    final data = await _get('/current-alerts?worker_id=$workerId');
    final list = data['alerts'] as List;
    return list.map((e) => WeatherAlert.fromJson(e)).toList();
  }

  // ─── Payouts ───────────────────────────────────────────────────────────────

  Future<List<PayoutRecord>> getPayouts(String workerId) async {
    final data = await _get('/worker/$workerId/payouts') as List;
    return data.map((e) => PayoutRecord.fromJson(e)).toList();
  }

  // ─── Coverage ──────────────────────────────────────────────────────────────

  Future<CoverageData> getCoverage(String workerId) async {
    final data = await _get('/coverage?worker_id=$workerId');
    return CoverageData.fromJson(data);
  }

  // ─── Session Ping ──────────────────────────────────────────────────────────

  Future<void> sessionPing({
    required String workerId,
    required double lat,
    required double lon,
    double movementKmDelta = 0,
    int deliveriesDoneDelta = 0,
  }) async {
    await _post('/session-ping', {
      'worker_id': workerId,
      'lat': lat,
      'lon': lon,
      'movement_km_delta': movementKmDelta,
      'deliveries_done_delta': deliveriesDoneDelta,
    });
  }

  // ─── Zone Detection (Registration Step 3) ─────────────────────────────────────

  Future<ZoneDetection> detectZone({
    required String workerId,
    required double lat,
    required double lon,
  }) async {
    final data = await _post('/detect-zone', {
      'worker_id': workerId,
      'lat': lat,
      'lon': lon,
    });
    return ZoneDetection.fromJson(data);
  }

  Future<String> registerComplete({
    required String workerId,
    required String planName,
    required double weeklyPremium,
    required String paymentRef,
  }) async {
    final data = await _post('/register/complete', {
      'worker_id': workerId,
      'plan_name': planName,
      'weekly_premium': weeklyPremium,
      'payment_ref': paymentRef,
    });
    return data['status'] ?? 'DONE';
  }

  // ─── Live Metrics (Real-time, every 30s) ───────────────────────────────────

  Future<LiveMetrics> getLiveMetrics(String workerId) async {
    final data = await _get('/live-metrics/$workerId');
    return LiveMetrics.fromJson(data);
  }

  Future<Map<String, dynamic>> locationUpdate({
    required String workerId,
    required double lat,
    required double lon,
  }) async {
    return await _post('/location-update', {
      'worker_id': workerId,
      'lat': lat,
      'lon': lon,
    });
  }

  // ─── Pricing Tiers (Dynamic based on earnings) ────────────────────────────

  Future<PricingResponse> getPricingTiers({String? workerId}) async {
    final path = workerId != null
        ? '/pricing-tiers?worker_id=$workerId'
        : '/pricing-tiers';
    final data = await _get(path);
    return PricingResponse.fromJson(data);
  }

  // ─── Alert History (With TTL) ───────────────────────────────────────────────

  Future<List<AlertRecord>> getAlertHistory(String workerId) async {
    final data = await _get('/alerts/$workerId');
    final list = data as List;
    return list.map((e) => AlertRecord.fromJson(e)).toList();
  }
}
