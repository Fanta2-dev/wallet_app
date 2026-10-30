import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/api_client.dart';
import '../core/backend.dart';
import '../core/nav.dart';
import '../models/models.dart';

/// État global : configuration, session JWT, utilisateur connecté.
class AuthState extends ChangeNotifier {
  static const _kToken = 'jwt_token';

  final AppConfig config = AppConfig();
  late final ApiClient api;
  late final Backend backend;

  bool loading = true;
  String? token;
  AppUser? user;

  /// JWT obtenu après validation OTP : utilisé pour définir le PIN avant d'ouvrir la session
  String? _registrationToken;

  AuthState() {
    api = ApiClient(config);
    api.onUnauthorized = _onUnauthorized;
    backend = Backend(api);
  }

  bool get isAuthenticated => token != null && user != null;

  Future<void> init() async {
    await config.load();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kToken);
    if (saved != null) {
      api.token = saved;
      try {
        user = await backend.me();
        token = saved;
      } catch (_) {
        api.token = null;
        await prefs.remove(_kToken);
      }
    }
    loading = false;
    notifyListeners();
  }

  // ───── connexion ─────

  Future<void> login(String phone, String pin) async {
    final t = await backend.login(phone, pin);
    final u = await backend.me(token: t);
    await _openSession(t, u);
  }

  // ───── inscription : init -> OTP -> PIN ─────

  Future<OtpInfo> registerInit(String phone, String email, String fullName) =>
      backend.registerInit(phone, email, fullName);

  Future<void> verifyOtp(String phone, String code) async {
    _registrationToken = await backend.verifyOtp(phone, code);
  }

  /// Définit le PIN puis ouvre la session
  Future<void> finishRegistration(String pin) async {
    final t = _registrationToken;
    if (t == null) throw ApiException('Validez d\'abord le code OTP.');
    await backend.setPin(pin, token: t);
    final u = await backend.me(token: t);
    _registrationToken = null;
    await _openSession(t, u);
  }

  Future<void> _openSession(String t, AppUser u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, t);
    api.token = t;
    token = t;
    user = u;
    notifyListeners();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> refreshUser() async {
    user = await backend.me();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    api.token = null;
    token = null;
    user = null;
    _registrationToken = null;
    notifyListeners();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  void _onUnauthorized() {
    if (token == null) return;
    logout();
    messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Session expirée, veuillez vous reconnecter.')),
    );
  }
}
