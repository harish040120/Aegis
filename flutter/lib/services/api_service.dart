import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => 'http://localhost:8010';
  static String get hubUrl => 'http://localhost:3015';

  static Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // ─── v6.0 LOGIN & AUTH ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String workerId, String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/login'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'phone': phone}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Login failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> verifyOtp(String workerId, String sessionId, String otpCode) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/verify-otp'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'session_id': sessionId, 'otp_code': otpCode}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('OTP verification failed: ${res.body}');
  }

  // ─── v6.0 REGISTRATION ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerProfile({
    required String workerId,
    required String name,
    required String platform,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/register/profile'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'name': name, 'platform': platform}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Profile registration failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> registerIncome({
    required String workerId,
    required double avgEarnings12w,
    required double targetDailyHours,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/register/income'),
      headers: _headers,
      body: jsonEncode({
        'worker_id': workerId,
        'avg_earnings_12w': avgEarnings12w,
        'target_daily_hours': targetDailyHours,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Income registration failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> registerLocation({
    required String workerId,
    required String city,
    required String zone,
    required double lat,
    required double lon,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/register/location'),
      headers: _headers,
      body: jsonEncode({
        'worker_id': workerId,
        'city': city,
        'zone': zone,
        'lat': lat,
        'lon': lon,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Location registration failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> sessionPing({
    required String workerId,
    required String sessionId,
    required double lat,
    required double lon,
    double? hoursOnline,
    double? movementKm,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/session-ping'),
      headers: _headers,
      body: jsonEncode({
        'worker_id': workerId,
        'session_id': sessionId,
        'lat': lat,
        'lon': lon,
        'hours_online': hoursOnline,
        'movement_km': movementKm,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Session ping failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> getHome(String workerId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/home?worker_id=$workerId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Home fetch failed: ${res.body}');
  }

  // ─── v6.0 SUBSCRIPTION ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> subscribe({
    required String workerId,
    required String planName,
    required double weeklyPremium,
    String paymentRef = 'demo_payment',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/subscribe'),
      headers: _headers,
      body: jsonEncode({
        'worker_id': workerId,
        'plan_name': planName,
        'weekly_premium': weeklyPremium,
        'payment_ref': paymentRef,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Subscription failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> getPolicy(String workerId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker/$workerId/policy'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Policy fetch failed: ${res.body}');
  }

  // ─── v6.0 KYC (OPTIONAL) ────────────────────────────────────────────
  static Future<Map<String, dynamic>> completeKyc(String workerId, String aadhaarNumber) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/complete-kyc'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'aadhaar_number': aadhaarNumber}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('KYC failed: ${res.body}');
  }

  // ─── ANALYSIS ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> triggerAnalysis({
    required String workerId,
    required double lat,
    required double lon,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/analyze'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'lat': lat, 'lon': lon}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Analysis failed: ${res.body}');
  }

  // ─── DASHBOARD DATA ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWorkerSummary(String workerId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker/$workerId/summary'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Summary fetch failed: ${res.body}');
  }

  static Future<List<dynamic>> getPayouts(String workerId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker/$workerId/payouts'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  // ─── LEGACY ENDPOINTS (for backward compat) ────────────────────────────
  static Future<Map<String, dynamic>> getWorkerByPhone(String phone) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker-by-phone?phone=$phone'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Worker not found for phone: $phone');
  }

  static Future<Map<String, dynamic>> registerWorker(Map<String, dynamic> workerData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/register'),
      headers: _headers,
      body: jsonEncode(workerData),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Registration failed: ${res.body}');
  }

  // ─── AI ASSISTANT ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> chatWithAI(String workerId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/assistant'),
      headers: _headers,
      body: jsonEncode({'worker_id': workerId, 'question': message}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI chat failed: ${res.body}');
  }
}