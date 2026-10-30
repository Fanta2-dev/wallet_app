import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/common.dart';

/// Permet de changer les adresses des microservices (utile sur un téléphone physique)
Future<void> showServerSettings(BuildContext context) async {
  final auth = context.read<AuthState>();
  final wallet = TextEditingController(text: auth.config.walletUrl);
  final service = TextEditingController(text: auth.config.serviceUrl);

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Serveurs backend'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Émulateur Android : http://10.0.2.2:PORT\n'
              'Téléphone physique : http://IP-DU-PC:PORT (même Wi-Fi)',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wallet,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'wallet-service', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: service,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'service-app', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await auth.config.reset();
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) showInfo(context, 'Adresses réinitialisées');
          },
          child: const Text('Par défaut'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            await auth.config.save(wallet.text, service.text);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) showInfo(context, 'Adresses enregistrées');
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
