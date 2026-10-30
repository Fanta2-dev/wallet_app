# wallet_app — Application mobile Flutter

Client mobile de la plateforme **Wallet & Prestations** (backend Spring Boot + PostgreSQL, voir le projet `projet-wallet`).

## Fonctionnalités
- **Inscription** en 3 étapes : informations → code OTP (simulé, affiché à l'écran) → choix du PIN
- **Connexion** téléphone + PIN (JWT conservé sur l'appareil) ; déconnexion automatique si la session expire
- **Portefeuille** : solde, dépôt, retrait (PIN), historique avec statuts (dont « À réessayer »)
- **Services** : catalogue, commande avec choix du responsable, paiement immédiat ou plus tard
- **Mes demandes** : statuts, **réessai de paiement** après un échec (compensation), annulation, détail avec tâches / ressources / délais (retards en rouge)
- **Profil** : modification, suppression du compte, paramètres serveur
- **Admin** (compte `+221770000000` / PIN `1234`) : toutes les demandes, ajout de tâches (ressource + délai), changement de statuts, catalogue, responsables, ressources, utilisateurs

## Installation (une seule fois)

Ce zip contient le code (`lib/`, `pubspec.yaml`). Les dossiers de plateforme Android/iOS sont générés par Flutter :

```bash
cd wallet_app
flutter create --platforms=android,ios --project-name wallet_app .
dart run tool/setup_android.dart      # autorise INTERNET + HTTP non chiffré (backend de dev)
flutter pub get
```

`flutter create .` ne remplace pas `lib/` ni `pubspec.yaml`. Pour le web, ajouter `web` à `--platforms`.

## Lancer

1. Démarrer le backend : `docker compose up --build -d` (dans `projet-wallet`).
2. Lancer l'app :
   ```bash
   flutter run
   ```

### Adresse du backend
| Cas | Adresses |
|---|---|
| **Émulateur Android** (défaut) | `http://10.0.2.2:8081` et `http://10.0.2.2:8082` |
| Simulateur iOS / web / desktop | `http://localhost:8081` et `http://localhost:8082` |
| **Téléphone réel** (même Wi-Fi que le PC) | `http://<IP-du-PC>:8081` / `:8082` — à saisir dans l'app via l'icône ⚙ de l'écran de connexion (ou `--dart-define=WALLET_URL=... --dart-define=SERVICE_URL=...`) |

Pensez à autoriser les ports 8081/8082 dans le pare-feu du PC pour un téléphone réel.

## Parcours de démonstration
1. **Créer un compte** → noter le code OTP affiché → définir un PIN.
2. **Portefeuille** → *Déposer* 50 000.
3. **Services** → *Création site web* (80 000) → choisir un responsable → *Payer maintenant* → le solde est insuffisant : message de refus, la demande reste « en attente de paiement ».
4. **Portefeuille** → déposer encore 50 000 → **Mes demandes** → *Réessayer le paiement* → la demande passe **Payée**.
5. Se déconnecter, se connecter en **admin** → onglet *Admin* → *Demandes* → ouvrir la demande → *Ajouter une tâche* (ressource, délai) → changer son statut.
6. Revenir en utilisateur : le détail de la demande affiche la tâche, la ressource et le délai.

## Structure
```
lib/
  main.dart               point d'entrée, routage connecté / non connecté
  config/app_config.dart  URLs des microservices
  core/                   client HTTP (JWT, erreurs), appels REST, formats
  models/models.dart      modèles JSON
  state/auth_state.dart   session, inscription, déconnexion (Provider)
  screens/                login, register, home + onglets, détail demande, admin
  widgets/                composants communs, parcours de paiement
```
Dépendances : `http`, `provider`, `shared_preferences`.
> Note : le JWT est stocké avec `shared_preferences` pour simplifier ; en production, utiliser `flutter_secure_storage`.
