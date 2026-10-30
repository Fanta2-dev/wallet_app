import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';

/// Affiche un message d'erreur (snackbar rouge)
void showError(BuildContext context, Object e) {
  final msg = e is ApiException ? e.message : (e is String ? e : 'Une erreur est survenue : $e');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Charge un Future et affiche : spinner / erreur + bouton Réessayer / contenu
class LoadView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  const LoadView({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          final msg = err is ApiException ? err.message : '$err';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text(msg, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

/// Puce colorée pour les statuts (demande, tâche, transaction)
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  static const Map<String, (String, Color)> _map = {
    'EN_ATTENTE_PAIEMENT': ('En attente de paiement', Colors.orange),
    'PAYEE': ('Payée', Colors.green),
    'EN_COURS': ('En cours', Colors.blue),
    'TERMINEE': ('Terminée', Colors.teal),
    'ANNULEE': ('Annulée', Colors.grey),
    'A_FAIRE': ('À faire', Colors.blueGrey),
    'SUCCESS': ('Réussi', Colors.green),
    'FAILED': ('Échoué', Colors.red),
    'PENDING_COMPENSATION': ('À réessayer', Colors.orange),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _map[status] ?? (status, Colors.grey);
    final color = entry.$2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(entry.$1,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Demande le PIN (champ masqué, 4 à 6 chiffres). Retourne null si annulé.
Future<String?> askPin(BuildContext context, {String title = 'Confirmez avec votre PIN'}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title),
  );
}

class _PinDialog extends StatefulWidget {
  final String title;
  const _PinDialog({required this.title});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _ctrl.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Le PIN contient 4 à 6 chiffres');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'PIN',
          errorText: _error,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }
}

/// Demande un montant (> 0). Retourne null si annulé.
Future<double?> askAmount(BuildContext context, {required String title, String confirm = 'Valider'}) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Montant (FCFA)',
            errorText: error,
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v == null || v < 1) {
                setState(() => error = 'Montant minimum : 1');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: Text(confirm),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String confirm = 'Confirmer', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Boîte de dialogue générique à plusieurs champs texte. Retourne les valeurs ou null.
Future<List<String>?> askFields(
  BuildContext context, {
  required String title,
  required List<String> labels,
  List<String>? initial,
  List<TextInputType>? types,
  String confirm = 'Enregistrer',
}) {
  final ctrls = List.generate(
      labels.length, (i) => TextEditingController(text: initial != null ? initial[i] : ''));
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: ctrls[i],
                  keyboardType: types != null ? types[i] : TextInputType.text,
                  decoration: InputDecoration(labelText: labels[i], border: const OutlineInputBorder()),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrls.map((c) => c.text.trim()).toList()),
          child: Text(confirm),
        ),
      ],
    ),
  );
}
