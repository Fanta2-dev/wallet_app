import 'package:flutter/material.dart';

/// Clé globale du navigateur : permet de revenir à l'écran racine
/// après connexion / déconnexion, depuis n'importe où.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
