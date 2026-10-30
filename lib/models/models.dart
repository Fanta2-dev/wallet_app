double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String _s(dynamic v) => v?.toString() ?? '';

class AppUser {
  final int id;
  final String phone;
  final String email;
  final String fullName;
  final double solde;
  final String role;
  final bool pinDefined;

  AppUser({
    required this.id,
    required this.phone,
    required this.email,
    required this.fullName,
    required this.solde,
    required this.role,
    required this.pinDefined,
  });

  bool get isAdmin => role == 'ADMIN';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        phone: _s(j['phone']),
        email: _s(j['email']),
        fullName: _s(j['fullName']),
        solde: _d(j['solde']),
        role: _s(j['role']).isEmpty ? 'USER' : _s(j['role']),
        pinDefined: j['pinDefined'] == true,
      );
}

class OtpInfo {
  final String message;
  final String code;
  final int validiteMinutes;
  OtpInfo(this.message, this.code, this.validiteMinutes);

  factory OtpInfo.fromJson(Map<String, dynamic> j) => OtpInfo(
        _s(j['message']),
        _s(j['codeOtp']),
        (j['validiteMinutes'] as num?)?.toInt() ?? 5,
      );
}

class WalletTx {
  final int id;
  final String type; // DEPOT | RETRAIT | PAIEMENT
  final String status; // SUCCESS | FAILED | PENDING_COMPENSATION
  final double amount;
  final String? reference;
  final String description;
  final DateTime? createdAt;

  WalletTx({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.reference,
    required this.description,
    required this.createdAt,
  });

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: (j['id'] as num).toInt(),
        type: _s(j['type']),
        status: _s(j['status']),
        amount: _d(j['amount']),
        reference: j['reference']?.toString(),
        description: _s(j['description']),
        createdAt: _dt(j['createdAt']),
      );
}

class ServiceOffre {
  final int id;
  final String nom;
  final String description;
  final double prix;
  ServiceOffre({required this.id, required this.nom, required this.description, required this.prix});

  factory ServiceOffre.fromJson(Map<String, dynamic> j) => ServiceOffre(
        id: (j['id'] as num).toInt(),
        nom: _s(j['nom']),
        description: _s(j['description']),
        prix: _d(j['prix']),
      );
}

class Responsable {
  final int id;
  final String nom;
  final String email;
  Responsable({required this.id, required this.nom, required this.email});

  factory Responsable.fromJson(Map<String, dynamic> j) =>
      Responsable(id: (j['id'] as num).toInt(), nom: _s(j['nom']), email: _s(j['email']));
}

class Ressource {
  final int id;
  final String nom;
  final String specialite;
  Ressource({required this.id, required this.nom, required this.specialite});

  factory Ressource.fromJson(Map<String, dynamic> j) =>
      Ressource(id: (j['id'] as num).toInt(), nom: _s(j['nom']), specialite: _s(j['specialite']));
}

class Demande {
  final int id;
  final int userId;
  final ServiceOffre service;
  final Responsable? responsable;
  final double montant;
  final String status;
  final DateTime? dateCreation;
  final DateTime? datePaiement;
  final int tentativesPaiement;
  final String? derniereErreurPaiement;

  Demande({
    required this.id,
    required this.userId,
    required this.service,
    required this.responsable,
    required this.montant,
    required this.status,
    required this.dateCreation,
    required this.datePaiement,
    required this.tentativesPaiement,
    required this.derniereErreurPaiement,
  });

  bool get enAttentePaiement => status == 'EN_ATTENTE_PAIEMENT';

  factory Demande.fromJson(Map<String, dynamic> j) => Demande(
        id: (j['id'] as num).toInt(),
        userId: (j['userId'] as num).toInt(),
        service: ServiceOffre.fromJson(j['service'] as Map<String, dynamic>),
        responsable: j['responsable'] == null
            ? null
            : Responsable.fromJson(j['responsable'] as Map<String, dynamic>),
        montant: _d(j['montant']),
        status: _s(j['status']),
        dateCreation: _dt(j['dateCreation']),
        datePaiement: _dt(j['datePaiement']),
        tentativesPaiement: (j['tentativesPaiement'] as num?)?.toInt() ?? 0,
        derniereErreurPaiement: j['derniereErreurPaiement']?.toString(),
      );
}

class Tache {
  final int id;
  final String titre;
  final Ressource ressource;
  final DateTime? delai;
  final String status; // A_FAIRE | EN_COURS | TERMINEE

  Tache({required this.id, required this.titre, required this.ressource, required this.delai, required this.status});

  bool get enRetard {
    if (delai == null || status == 'TERMINEE') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return delai!.isBefore(today);
  }

  factory Tache.fromJson(Map<String, dynamic> j) => Tache(
        id: (j['id'] as num).toInt(),
        titre: _s(j['titre']),
        ressource: Ressource.fromJson(j['ressource'] as Map<String, dynamic>),
        delai: _dt(j['delai']),
        status: _s(j['status']),
      );
}

/// Résultat d'une tentative de paiement (HTTP 200 = succès, 402 = refus réessayable)
class PaiementResult {
  final bool success;
  final String message;
  final Demande? demande;
  PaiementResult(this.success, this.message, this.demande);

  factory PaiementResult.fromJson(Map<String, dynamic> j) => PaiementResult(
        j['success'] == true,
        _s(j['message']),
        j['demande'] == null ? null : Demande.fromJson(j['demande'] as Map<String, dynamic>),
      );
}
