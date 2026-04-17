// lib/services/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyToken = 'session_token';
  static const _keyWorkerId = 'worker_id';
  static const _keyPhone = 'phone';

  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _workerId;
  String? _phone;
  bool _isNewRegistration = false;
  RegistrationStep _resumedStep = RegistrationStep.profile;
  bool _initialized = false;

  String? get token => _token;
  String? get workerId => _workerId;
  String? get phone => _phone;
  bool get isLoggedIn => _token != null;
  bool get isNewRegistration => _isNewRegistration;
  RegistrationStep get resumedStep => _resumedStep;
  bool get initialized => _initialized;

  ApiService get api => ApiService(token: _token);

  // ─── Init / Restore session ──────────────────────────────────────────────
  Future<void> init() async {
    _token = await _storage.read(key: _keyToken);
    _workerId = await _storage.read(key: _keyWorkerId);
    _phone = await _storage.read(key: _keyPhone);
    _initialized = true;
    notifyListeners();
  }

  // ─── Login ───────────────────────────────────────────────────────────────
  Future<LoginResponse> login(String? workerId, String phone) async {
    final svc = ApiService();
    final res = await svc.login(workerId, phone);

    _token = res.sessionToken;
    _workerId = res.workerId;
    _phone = phone;
    _isNewRegistration = res.isNewRegistration;
    _resumedStep = registrationStepFromString(res.resumedStep);

    await _storage.write(key: _keyToken, value: _token);
    await _storage.write(key: _keyWorkerId, value: _workerId);
    await _storage.write(key: _keyPhone, value: phone);

    notifyListeners();
    return res;
  }

  // ─── OTP Verify ──────────────────────────────────────────────────────────
  Future<bool> verifyOtp(String otp) async {
    final svc = ApiService(token: _token);

    return svc.verifyOtp(_workerId!, _token!, otp);
  }

  // ─── Logout ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.deleteAll();
    _token = null;
    _workerId = null;
    _phone = null;
    notifyListeners();
  }
}
