import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import 'common.dart';

/// Parcours de paiement d'une demande (utilisé depuis le catalogue et « Mes demandes »).
///
/// 1. demande le PIN
/// 2. appelle service-app -> wallet
/// 3. succès : demande PAYEE ; échec : la demande reste EN_ATTENTE_PAIEMENT
///    (compensation) et l'utilisateur peut réessayer plus tard.
///
/// Retourne true si la demande est payée.
Future<bool> runPaymentFlow(BuildContext context, Demande demande) async {
  final auth = context.read<AuthState>();
  final retry = demande.tentativesPaiement > 0;

  final pin = await askPin(context, title: 'Payer ${fmtMoney(demande.montant)}');
  if (pin == null) return false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  PaiementResult? result;
  Object? error;
  try {
    result = await auth.backend.payer(demande.id, pin, retry: retry);
  } catch (e) {
    error = e;
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // ferme le spinner
  if (!context.mounted) return false;

  if (error != null) {
    showError(context, error);
    return false;
  }

  if (result!.success) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Paiement réussi'),
        content: Text('La demande n°${demande.id} est payée.\n${result!.message}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    return true;
  }

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
      title: const Text('Paiement non effectué'),
      content: Text('${result!.message}\n\n'
          'Votre demande reste « en attente de paiement ». Vous pourrez la payer plus tard '
          'depuis l\'onglet « Mes demandes » (par exemple après un dépôt).'),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris'))],
    ),
  );
  return false;
}
