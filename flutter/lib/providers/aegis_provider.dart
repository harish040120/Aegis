import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

enum AppState { initial, loading, authenticated, unauthenticated, error }

class AegisProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _workerIdKey = 'aegis_worker_id';
  static const _workerPhoneKey = 'aegis_worker_phone';
  static const _sessionTokenKey = 'aegis_session_token';

  AppState _appState = AppState.initial;
  Worker? _worker;
  WeatherData? _weather;
  RiskResult? _riskResult;
  List<DisruptionAlert> _alerts = [];
  List<Claim> _claims = [];
  
  String? _workerId;
  String? _workerName;
  String? _workerZone;
  String? _kycStatus;
  String? _sessionToken;
  String? _sessionId;
  String? _registrationStep;
  
  double? _userLat;
  double? _userLon;
  
  String? _activePolicyId;
  String? _activePlanName;
  double? _weeklyPremium;
  DateTime? _coverageEnd;
  bool _hasActivePlan = false;

  Map<String, dynamic>? _lastAnalysisResult;
  bool _loadingWeather = false;
  bool _loadingAlerts = false;
  bool _loadingClaims = false;
  String? _demoOtp;
  String? _errorMessage;
  
  Timer? _alertPollingTimer;
  final Map<String, DateTime> _alertFirstDetected = {};
  final Set<String> _alreadyTriggeredPayouts = {};

  AppState get appState         => _appState;
  Worker?  get worker          => _worker;
  WeatherData? get weather     => _weather;
  RiskResult?  get riskResult  => _riskResult;
  List<DisruptionAlert> get alerts => _alerts;
  List<Claim> get claims       => _claims;
  String?  get workerId        => _workerId;
  String?  get workerName      => _workerName;
  String?  get workerZone      => _workerZone;
  bool     get hasActivePlan   => _hasActivePlan;
  String?  get activePlanName  => _activePlanName;
  double?  get weeklyPremium   => _weeklyPremium;
  DateTime? get coverageEnd    => _coverageEnd;
  String?  get sessionToken   => _sessionToken;
  String?  get registrationStep => _registrationStep;
  
  double get basePremium       => _weeklyPremium ?? 34.0;
  Map<String, dynamic>? get lastResult => _lastAnalysisResult;
  
  bool get loadingWeather      => _loadingWeather;
  bool get loadingAlerts       => _loadingAlerts;
  bool get loadingClaims       => _loadingClaims;
  bool get isLoggedIn          => _workerId != null && _sessionToken != null;
  double get dynamicDailyBase  => (_worker?.weeklyEarningsAvg ?? 1800) / 8.0;
  
  String get routeTarget {
    if (_workerId == null || _sessionToken == null) return '/login';
    if (_registrationStep != 'DONE') return '/register';
    if (!_hasActivePlan) return '/plan';
    return '/home';
  }

  Future<void> init() async {
    await initUserLocation();
    await _restoreSession();
    if (_workerId != null) {
      await fetchActivePolicy();
    }
    notifyListeners();
  }

  void logout() {
    _workerId = null;
    _workerName = null;
    _sessionToken = null;
    _sessionId = null;
    _hasActivePlan = false;
    _lastAnalysisResult = null;
    _claims = [];
    _appState = AppState.unauthenticated;
    _alertFirstDetected.clear();
    _alreadyTriggeredPayouts.clear();
    _stopAlertPolling();
    _clearSession();
    notifyListeners();
  }

  // ─── v6.0 LOGIN FLOW ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String workerId, String phone) async {
    _appState = AppState.loading;
    notifyListeners();
    
    try {
      final data = await ApiService.login(workerId, phone);
      _demoOtp = data['demo_otp'];
      _sessionId = data['session_id']?.toString();
      _workerId = workerId;
      notifyListeners();
      return {
        'session_id': _sessionId,
        'demo_otp': _demoOtp,
      };
    } catch (e) {
      _appState = AppState.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyOtp(String workerId, String sessionId, String otpCode) async {
    if (otpCode.isEmpty) throw Exception('Please enter OTP');
    
    _appState = AppState.loading;
    notifyListeners();
    
    try {
      final data = await ApiService.verifyOtp(workerId, sessionId, otpCode);
      _sessionToken = data['session_id']?.toString() ?? sessionId;
      _registrationStep = data['registration_step']?.toString() ?? 'DONE';
      _workerId = workerId;
      
      final workerData = data['worker'];
      if (workerData != null) {
        _workerId = workerData['worker_id'] ?? workerId;
        _workerName = workerData['name'];
        _workerZone = workerData['zone'];
        _kycStatus = workerData['kyc_status'];
        _registrationStep = workerData['registration_step'] ?? 'DONE';
        _hasActivePlan = workerData['has_active_policy'] ?? false;
      }
      
      await _persistSession();
      await fetchActivePolicy();
      await refreshAll();
      
      _appState = AppState.authenticated;
      notifyListeners();
    } catch (e) {
      _appState = AppState.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─── v6.0 REGISTRATION FLOW ────────────────────────────────────────
  Future<void> registerProfile({
    required String name,
    required String platform,
  }) async {
    if (_workerId == null) return;
    
    _appState = AppState.loading;
    notifyListeners();
    
    try {
      final data = await ApiService.registerProfile(
        workerId: _workerId!,
        name: name,
        platform: platform,
      );
      _registrationStep = 'INCOME';
      _appState = AppState.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> registerIncome({
    required double avgEarnings12w,
    required double targetDailyHours,
  }) async {
    if (_workerId == null) return;
    
    _appState = AppState.loading;
    notifyListeners();
    
    try {
      await ApiService.registerIncome(
        workerId: _workerId!,
        avgEarnings12w: avgEarnings12w,
        targetDailyHours: targetDailyHours,
      );
      _registrationStep = 'LOCATION';
      _appState = AppState.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> registerLocation({
    required String city,
    required String zone,
    double? lat,
    double? lon,
  }) async {
    if (_workerId == null) return;
    
    _appState = AppState.loading;
    notifyListeners();
    
    try {
      await ApiService.registerLocation(
        workerId: _workerId!,
        city: city,
        zone: zone,
        lat: lat ?? _userLat ?? 13.0827,
        lon: lon ?? _userLon ?? 80.2707,
      );
      _registrationStep = 'DONE';
      await _persistSession();
      await fetchActivePolicy();
      _appState = AppState.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─── SESSION & HOME ────────────────────────────────────────────
  Future<void> fetchHomeData() async {
    if (_workerId == null) return;
    
    try {
      final data = await ApiService.getHome(_workerId!);
      _mapHomeData(data);
      notifyListeners();
    } catch (e) {
      debugPrint('fetchHomeData error: $e');
    }
  }

  void _mapHomeData(Map<String, dynamic> data) {
    _workerId = data['worker_id'] ?? _workerId;
    _workerName = data['name'];
    _workerZone = data['zone'];
    _registrationStep = data['registration_step'];
    _hasActivePlan = data['has_active_policy'] ?? false;
    
    if (data['plan_name'] != null) {
      _activePlanName = data['plan_name'];
    }
    if (data['coverage_end'] != null) {
      _coverageEnd = DateTime.tryParse(data['coverage_end']);
    }
  }

  void _mapWorkerData(Map<String, dynamic> data) {
    _workerId      = data['worker_id'];
    _workerName    = data['name'];
    _workerZone   = data['zone'];
    _kycStatus    = data['kyc_status'];
    _registrationStep = data['registration_step'];
    _hasActivePlan = data['has_active_policy'] ?? false;
    _worker = Worker.fromJson(data);
  }

  Future<void> _persistSession() async {
    if (_workerId == null) return;
    await _storage.write(key: _workerIdKey, value: _workerId);
    if (_sessionToken != null) {
      await _storage.write(key: _sessionTokenKey, value: _sessionToken);
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: _workerIdKey);
    await _storage.delete(key: _workerPhoneKey);
    await _storage.delete(key: _sessionTokenKey);
  }

  Future<void> _restoreSession() async {
    final savedWorkerId = await _storage.read(key: _workerIdKey);
    final savedToken = await _storage.read(key: _sessionTokenKey);
    
    if (savedWorkerId == null || savedWorkerId.isEmpty) return;
    if (savedToken == null || savedToken.isEmpty) return;
    
    try {
      final data = await ApiService.getHome(savedWorkerId);
      _workerId = savedWorkerId;
      _sessionToken = savedToken;
      _mapHomeData(data);
    } catch (_) {
      await _clearSession();
    }
  }

  // ─── SUBSCRIPTION ──────────────────────────────────────────────
  Future<bool> subscribe({
    required String planTier,
    required double premium,
  }) async {
    if (_workerId == null) return false;
    
    try {
      final data = await ApiService.subscribe(
        workerId: _workerId!,
        planName: planTier.toUpperCase(),
        weeklyPremium: premium,
      );

      _hasActivePlan  = true;
      _activePlanName = data['plan_name'];
      _weeklyPremium  = (data['weekly_premium'] as num).toDouble();
      _coverageEnd    = DateTime.parse(data['coverage_end']);
      
      if (_worker != null) {
        _worker = Worker(
          id: _worker!.id,
          name: _worker!.name,
          phone: _worker!.phone,
          platform: _worker!.platform,
          city: _worker!.city,
          zone: _worker!.zone,
          kycComplete: _worker!.kycComplete,
          subscribed: true,
          upiId: _worker!.upiId,
          weeklyEarningsAvg: _worker!.weeklyEarningsAvg,
          riskScore: _worker!.riskScore,
          weeklyPremium: _weeklyPremium!,
          planTier: planTier,
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Subscribe error: $e');
      return false;
    }
  }

  Future<void> fetchActivePolicy() async {
    if (_workerId == null) return;
    try {
      final data = await ApiService.getPolicy(_workerId!);
      _hasActivePlan  = true;
      _activePlanName = data['plan_name'];
      _weeklyPremium  = (data['weekly_premium'] as num).toDouble();
      _coverageEnd    = DateTime.parse(data['coverage_end']);
      notifyListeners();
    } catch (e) {
      _hasActivePlan = false;
      notifyListeners();
    }
  }

  // ─── REFRESH & ALERTS ─────────────────────��─��─────────────────
  Future<void> refreshAll() async {
    if (_workerId == null) return;
    await Future.wait([
      fetchClaims(),
      fetchAlerts(immediate: true),
      fetchWeatherAndScore(),
    ]);
  }

  Future<void> fetchClaims() async {
    if (_workerId == null) return;
    _loadingClaims = true;
    notifyListeners();
    try {
      final list = await ApiService.getPayouts(_workerId!);
      _claims = list.map((j) => Claim.fromJson(j)).toList();
    } catch (e) {
      debugPrint('fetchClaims error: $e');
    }
    _loadingClaims = false;
    notifyListeners();
  }

  Future<void> fetchAlerts({bool immediate = false}) async {
    if (_workerId == null) return;
    _loadingAlerts = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${ApiService.hubUrl}/api/current-alerts?worker_id=$_workerId')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alertsData = data['alerts'] as List<dynamic>? ?? [];
        final now = DateTime.now();
        final List<DisruptionAlert> detectedAlerts = [];
        final List<DisruptionAlert> confirmedAlerts = [];
        
        for (final alertData in alertsData) {
          final alertKey = alertData['type'] as String;
          if (alertData['is_fraud'] == true) continue;
          
          _alertFirstDetected.putIfAbsent(alertKey, () => now);
          final detectedTime = _alertFirstDetected[alertKey]!;
          final minutesActive = now.difference(detectedTime).inMinutes;
          final isConfirmed = minutesActive >= 5;
          
          final metricVal = (alertData['metric'] as num).toDouble();
          final triggerPctVal = ((alertData['trigger_pct'] as num) * 100).toInt();
          
          final alert = DisruptionAlert(
            id: '${alertKey}_${detectedTime.millisecondsSinceEpoch}',
            type: alertKey,
            typeLabel: alertData['typeLabel'] as String,
            severity: alertData['severity'] as String,
            metric: metricVal,
            threshold: (alertData['threshold'] as num).toDouble(),
            zone: _workerZone ?? 'Chennai-Central',
            description: isConfirmed 
                ? 'Confirmed: $triggerPctVal% payout' 
                : 'Pending ($minutesActive/5 min)',
            detectedAt: detectedTime,
          );
          
          detectedAlerts.add(alert);
          if (isConfirmed && !_alreadyTriggeredPayouts.contains(alertKey)) {
            confirmedAlerts.add(alert);
            _alreadyTriggeredPayouts.add(alertKey);
          }
        }
        
        if (immediate) {
          _alerts = detectedAlerts;
          for (final alert in confirmedAlerts) {
            await _triggerPayoutForAlert(alert);
          }
        } else {
          _alerts = detectedAlerts.where((alert) => alert.isActiveFor5Minutes).toList();
          for (final alert in _alerts) {
            if (!_alreadyTriggeredPayouts.contains(alert.type)) {
              await _triggerPayoutForAlert(alert);
              _alreadyTriggeredPayouts.add(alert.type);
            }
          }
        }
        _cleanupOldAlerts();
      }
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
    }
    _loadingAlerts = false;
    notifyListeners();
  }
  
  void _cleanupOldAlerts() {
    final now = DateTime.now();
    _alerts = _alerts.where((alert) {
      if (alert.detectedAt == null) return false;
      final minutesAgo = now.difference(alert.detectedAt!).inMinutes;
      return minutesAgo < 10;
    }).toList();
  }

  Future<void> _triggerPayoutForAlert(DisruptionAlert alert) async {
    if (_workerId == null) return;
    try {
      final coords = getCurrentCoords();
      final response = await http.post(
        Uri.parse('${ApiService.hubUrl}/api/trigger-payout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'worker_id': _workerId,
          'alert_type': alert.typeLabel,
          'lat': coords['lat'],
          'lon': coords['lon'],
        }),
      );
      if (response.statusCode == 200) {
        await Future.delayed(const Duration(milliseconds: 500));
        await fetchClaims();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Trigger payout error: $e');
    }
  }

  Future<void> fetchWeatherAndScore() async {
    if (_workerId == null) return;
    _loadingWeather = true;
    notifyListeners();
    try {
      await runAnalysis();
    } catch (_) {}
    _loadingWeather = false;
    notifyListeners();
  }

  void startRealTimeEngine() {
    refreshAll();
    _startAlertPolling();
  }
  
  void _startAlertPolling() {
    _stopAlertPolling();
    _alertPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchAlerts(immediate: false);
    });
  }
  
  void _stopAlertPolling() {
    _alertPollingTimer?.cancel();
    _alertPollingTimer = null;
  }
  
  @override
  void dispose() {
    _stopAlertPolling();
    super.dispose();
  }

  // ─── ANALYSIS ────────────────────────────────────────────────
  Future<void> runAnalysis() async {
    if (_workerId == null) return;
    final coords = getCurrentCoords();
    try {
      final result = await ApiService.triggerAnalysis(
        workerId: _workerId!,
        lat: coords['lat']!,
        lon: coords['lon']!,
      );
      _lastAnalysisResult = result;
      
      if (result['status'] != 'NO_COVERAGE') {
        final analytics = result['analytics'];
        final payout = result['payout'];
        final premiumUpdate = result['premium_update'];
        
        _riskResult = RiskResult(
          score: ((analytics['risk']['score'] ?? 5.0) * 10).toInt(),
          band: analytics['risk']['level'] ?? 'LOW',
          multiplier: 1.0,
          weeklyPremium: (premiumUpdate['weekly_premium'] as num).toDouble(),
          dailyCoverage: (payout['amount'] as num).toDouble(),
          maxWeekly: (payout['amount'] as num).toDouble() * 7.0,
          breakdown: {
            'Income Drop': '${(analytics['income']['drop'] as num).toDouble()}%',
            'Income Severity': analytics['income']['severity'] ?? 'LOW',
            'Trigger': payout['trigger'] ?? 'Base Coverage',
            'Status': result['status'] ?? 'APPROVED',
          },
        );
      }

      try {
        final weatherResponse = await http.get(
          Uri.parse('${ApiService.hubUrl}/api/risk-data?lat=${coords['lat']}&lon=${coords['lon']}&worker_id=$_workerId')
        );
        if (weatherResponse.statusCode == 200) {
          final weatherData = jsonDecode(weatherResponse.body);
          final w = weatherData['external_disruption']['weather'];
          final aq = weatherData['external_disruption']['air_quality'];
          
          _weather = WeatherData(
            tempC: (w['temp'] as num).toDouble(), 
            rainfallMm3h: (w['rain_1h'] as num).toDouble(), 
            windKmh: 12.0, 
            aqi: (aq['pm25'] as num).toInt(), 
            description: _getWeatherDescription(w['temp'], w['rain_1h']), 
            city: weatherData['location']['zone'] ?? 'Chennai', 
            fetchedAt: DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('Weather fetch error: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Analysis error: $e');
    }
  }
  
  String _getWeatherDescription(num temp, num rain) {
    if ((rain as num) > 45) return 'Heavy Rain';
    if ((rain as num) > 15) return 'Light Rain';
    if ((temp as num) > 36) return 'Extreme Heat';
    if ((temp as num) > 30) return 'Hot';
    return 'Clear';
  }

  // ─── LOCATION HELPERS ────────────────────────────────────────
  Map<String, double> _getZoneCoords(String zone) {
    const coords = {
      'Chennai-North':   {'lat': 13.1123, 'lon': 80.2981},
      'Chennai-South':   {'lat': 13.0345, 'lon': 80.2442},
      'Chennai-East':    {'lat': 13.0678, 'lon': 80.2356},
      'Chennai-Central': {'lat': 13.0827, 'lon': 80.2707},
      'Coimbatore-Central': {'lat': 11.0168, 'lon': 76.9558},
    };
    return coords[zone] ?? {'lat': 13.0827, 'lon': 80.2707};
  }

  Future<void> initUserLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        _userLat = position.latitude;
        _userLon = position.longitude;
        final detectedZone = LocationService.detectZoneFromCoords(_userLat!, _userLon!);
        _workerZone = detectedZone;
        notifyListeners();
      }
    } catch (_) {
      _workerZone = 'Chennai-Central';
    }
  }

  Map<String, double> getCurrentCoords() {
    if (_userLat != null && _userLon != null) {
      return {'lat': _userLat!, 'lon': _userLon!};
    }
    return _getZoneCoords(_workerZone ?? 'Chennai-Central');
  }

  Future<Map<String, dynamic>> getZoneFromGps(double lat, double lon) async {
    return {
      'city': 'Chennai',
      'zone': LocationService.detectZoneFromCoords(lat, lon)
    };
  }

  // ─── CLAIMS & KYC ─────────────────────────────────────────────
  Future<void> completeKyc(String aadhaarNumber) async {
    if (_workerId == null) return;
    await ApiService.completeKyc(_workerId!, aadhaarNumber);
    notifyListeners();
  }

  Future<void> submitClaim(String alertId) async {
    if (_workerId == null) return;
    try {
      final coords = getCurrentCoords();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/v1/submit-claim'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'worker_id': _workerId,
          'alert_type': alertId,
          'lat': coords['lat'],
          'lon': coords['lon'],
        }),
      );
      if (response.statusCode == 200) {
        await fetchClaims();
      }
    } catch (e) {
      debugPrint('Submit claim error: $e');
    }
  }

  Future<void> triggerClaimAndPayout(String alertType) async {
    if (_workerId == null) return;
    final coords = getCurrentCoords();
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/v1/submit-claim'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'worker_id': _workerId,
          'alert_type': alertType,
          'lat': coords['lat'],
          'lon': coords['lon'],
        }),
      );
      if (response.statusCode == 200) {
        await fetchClaims();
        await fetchAlerts(immediate: true);
      }
    } catch (e) {
      debugPrint('Trigger claim error: $e');
    }
  }
}