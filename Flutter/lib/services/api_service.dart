import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use localhost for Docker - update to host IP for external access
  static String get baseUrl => 'http://localhost:8010';
  static String get hubUrl => 'http://localhost:3015';

  // ─── CORE ANALYSIS ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> triggerAnalysis({
    required String workerId,
    required double lat,
    required double lon,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'worker_id': workerId, 'lat': lat, 'lon': lon}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Analysis failed: ${res.body}');
  }

  // ─── AUTH & ONBOARDING ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWorkerByPhone(String phone) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker-by-phone?phone=$phone'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Worker not found for phone: $phone');
  }

  static Future<Map<String, dynamic>> registerWorker(Map<String, dynamic> workerData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(workerData),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Registration failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> completeKYC(String workerId, Map<String, dynamic> kycData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/complete-kyc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'worker_id': workerId, ...kycData}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('KYC submission failed: ${res.body}');
  }

  // ─── SUBSCRIPTION ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> subscribe(String workerId, String planName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'worker_id': workerId, 'plan_name': planName}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Subscription failed: ${res.body}');
  }

  static Future<Map<String, dynamic>> getPolicy(String workerId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/worker/$workerId/policy'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Policy fetch failed: ${res.body}');
  }

  // ─── DASHBOARD ──────────────────────────────────────────────────────────────
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

  // ─── AI ASSISTANT ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> chatWithAI(String workerId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/assistant'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'worker_id': workerId, 'message': message}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI chat failed: ${res.body}');
  }
}