import '../models/models.dart';
import 'api_client.dart';

typedef Json = Map<String, dynamic>;

List<Json> _list(dynamic body) => (body as List).cast<Json>();

/// Tous les appels REST vers wallet-service (:8081) et service-app (:8082)
class Backend {
  final ApiClient api;
  Backend(this.api);

  String get _w => api.config.walletUrl;
  String get _s => api.config.serviceUrl;

  // ───────────── wallet-service : authentification ─────────────

  Future<OtpInfo> registerInit(String phone, String email, String fullName) async {
    final b = await api.call('POST', _w, '/api/auth/register/init',
        body: {'phone': phone, 'email': email, 'fullName': fullName});
    return OtpInfo.fromJson(b as Json);
  }

  /// Retourne le JWT (le compte est alors activé mais le PIN reste à définir)
  Future<String> verifyOtp(String phone, String code) async {
    final b = await api.call('POST', _w, '/api/auth/register/verify-otp',
        body: {'phone': phone, 'code': code});
    return (b as Json)['token'] as String;
  }

  Future<void> setPin(String pin, {String? token}) async {
    await api.call('POST', _w, '/api/auth/pin', body: {'pin': pin}, tokenOverride: token);
  }

  /// Retourne le JWT
  Future<String> login(String phone, String pin) async {
    final b = await api.call('POST', _w, '/api/auth/login', body: {'phone': phone, 'pin': pin});
    return (b as Json)['token'] as String;
  }

  Future<AppUser> me({String? token}) async {
    final b = await api.call('GET', _w, '/api/users/me', tokenOverride: token);
    return AppUser.fromJson(b as Json);
  }

  // ───────────── wallet-service : CRUD utilisateurs (NB2) ─────────────

  Future<List<AppUser>> users() async {
    final b = await api.call('GET', _w, '/api/users');
    return _list(b).map(AppUser.fromJson).toList();
  }

  Future<AppUser> updateUser(int id, String phone, String email, String fullName) async {
    final b = await api.call('PUT', _w, '/api/users/$id',
        body: {'phone': phone, 'email': email, 'fullName': fullName});
    return AppUser.fromJson(b as Json);
  }

  Future<void> deleteUser(int id) async {
    await api.call('DELETE', _w, '/api/users/$id');
  }

  // ───────────── wallet-service : portefeuille ─────────────

  Future<double> balance() async {
    final b = await api.call('GET', _w, '/api/wallet/balance');
    final v = (b as Json)['solde'];
    return v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  }

  Future<void> deposit(double amount) async {
    await api.call('POST', _w, '/api/wallet/deposit', body: {'amount': amount});
  }

  Future<void> withdraw(double amount, String pin) async {
    await api.call('POST', _w, '/api/wallet/withdraw', body: {'amount': amount, 'pin': pin});
  }

  Future<List<WalletTx>> transactions() async {
    final b = await api.call('GET', _w, '/api/wallet/transactions');
    return _list(b).map(WalletTx.fromJson).toList();
  }

  // ───────────── service-app : catalogue, responsables, ressources ─────────────

  Future<List<ServiceOffre>> services() async =>
      _list(await api.call('GET', _s, '/api/services')).map(ServiceOffre.fromJson).toList();

  Future<void> createService(String nom, String description, double prix) async {
    await api.call('POST', _s, '/api/services',
        body: {'nom': nom, 'description': description, 'prix': prix});
  }

  Future<List<Responsable>> responsables() async =>
      _list(await api.call('GET', _s, '/api/responsables')).map(Responsable.fromJson).toList();

  Future<void> createResponsable(String nom, String email) async {
    await api.call('POST', _s, '/api/responsables',
        body: {'nom': nom, if (email.isNotEmpty) 'email': email});
  }

  Future<List<Ressource>> ressources() async =>
      _list(await api.call('GET', _s, '/api/ressources')).map(Ressource.fromJson).toList();

  Future<void> createRessource(String nom, String specialite) async {
    await api.call('POST', _s, '/api/ressources', body: {'nom': nom, 'specialite': specialite});
  }

  // ───────────── service-app : demandes ─────────────

  /// Utilisateur : ses demandes. Admin : toutes les demandes.
  Future<List<Demande>> demandes() async =>
      _list(await api.call('GET', _s, '/api/demandes')).map(Demande.fromJson).toList();

  Future<Demande> demande(int id) async =>
      Demande.fromJson(await api.call('GET', _s, '/api/demandes/$id') as Json);

  Future<Demande> createDemande(int serviceId, int responsableId) async {
    final b = await api.call('POST', _s, '/api/demandes',
        body: {'serviceId': serviceId, 'responsableId': responsableId});
    return Demande.fromJson(b as Json);
  }

  /// Paiement via le wallet. 200 = payée ; 402 = refusée mais réessayable (compensation).
  Future<PaiementResult> payer(int demandeId, String pin, {bool retry = false}) async {
    final res = await api.send('POST', _s, '/api/demandes/$demandeId/${retry ? 'reessayer' : 'payer'}',
        body: {'pin': pin});
    if (res.status == 200 || res.status == 402) {
      return PaiementResult.fromJson(res.body as Json);
    }
    if (res.status == 401) {
      throw ApiException('Session expirée, reconnectez-vous.', status: 401);
    }
    throw ApiException(res.errorMessage, status: res.status);
  }

  Future<Demande> updateDemandeStatus(int id, String status) async {
    final b = await api.call('PATCH', _s, '/api/demandes/$id/status', body: {'status': status});
    return Demande.fromJson(b as Json);
  }

  // ───────────── service-app : tâches ─────────────

  Future<List<Tache>> taches(int demandeId) async =>
      _list(await api.call('GET', _s, '/api/demandes/$demandeId/taches')).map(Tache.fromJson).toList();

  Future<void> createTache(int demandeId, String titre, int ressourceId, String delaiIso) async {
    await api.call('POST', _s, '/api/demandes/$demandeId/taches',
        body: {'titre': titre, 'ressourceId': ressourceId, 'delai': delaiIso});
  }

  Future<void> updateTacheStatus(int tacheId, String status) async {
    await api.call('PATCH', _s, '/api/taches/$tacheId/status', body: {'status': status});
  }
}
