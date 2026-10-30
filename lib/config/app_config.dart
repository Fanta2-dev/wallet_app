import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adresses des deux microservices.
///
/// Valeurs par défaut :
///  - émulateur Android : 10.0.2.2 (alias de la machine hôte)
///  - iOS simulateur / web / desktop : localhost
///  - téléphone physique : saisir l'IP du PC (ex. http://192.168.1.20:8081) via l'icône ⚙ de l'écran de connexion
///
/// On peut aussi les fixer à la compilation :
///   flutter run --dart-define=WALLET_URL=http://192.168.1.20:8081 --dart-define=SERVICE_URL=http://192.168.1.20:8082
class AppConfig {
  static const _kWallet = 'wallet_url';
  static const _kService = 'service_url';

  static const String _definedWallet = String.fromEnvironment('WALLET_URL');
  static const String _definedService = String.fromEnvironment('SERVICE_URL');

  String walletUrl = '';
  String serviceUrl = '';

  static String get _host =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ? '10.0.2.2' : 'localhost';

  String get defaultWalletUrl => _definedWallet.isNotEmpty ? _definedWallet : 'http://$_host:8081';
  String get defaultServiceUrl => _definedService.isNotEmpty ? _definedService : 'http://$_host:8082';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    walletUrl = prefs.getString(_kWallet) ?? defaultWalletUrl;
    serviceUrl = prefs.getString(_kService) ?? defaultServiceUrl;
  }

  Future<void> save(String wallet, String service) async {
    walletUrl = _clean(wallet);
    serviceUrl = _clean(service);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWallet, walletUrl);
    await prefs.setString(_kService, serviceUrl);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWallet);
    await prefs.remove(_kService);
    walletUrl = defaultWalletUrl;
    serviceUrl = defaultServiceUrl;
  }

  static String _clean(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
