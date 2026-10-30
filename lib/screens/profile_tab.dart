import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/common.dart';
import 'settings_dialog.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _edit(BuildContext context) async {
    final auth = context.read<AuthState>();
    final u = auth.user!;
    final values = await askFields(
      context,
      title: 'Modifier mon profil',
      labels: ['Nom complet', 'Email', 'Téléphone'],
      initial: [u.fullName, u.email, u.phone],
      types: [TextInputType.name, TextInputType.emailAddress, TextInputType.phone],
    );
    if (values == null) return;
    try {
      await auth.backend.updateUser(u.id, values[2], values[1], values[0]);
      await auth.refreshUser();
      if (context.mounted) showInfo(context, 'Profil mis à jour');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final auth = context.read<AuthState>();
    final ok = await confirmDialog(
      context,
      'Supprimer mon compte',
      'Cette action est définitive : votre compte wallet et votre solde seront supprimés.',
      confirm: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    try {
      await auth.backend.deleteUser(auth.user!.id);
      await auth.logout();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final u = auth.user;
    if (u == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: Text(
                  u.fullName.isEmpty ? '?' : u.fullName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF635BFF)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(u.email, style: const TextStyle(color: Colors.white70)),
                    if (u.isAdmin) const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Administrateur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 2),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.phone), title: const Text('Téléphone'), subtitle: Text(u.phone)),
            ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(u.email)),
            ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Identifiant du compte wallet'),
                subtitle: Text('#${u.id}')),
          ]),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.edit),
          label: const Text('Modifier mon profil'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showServerSettings(context),
          icon: const Icon(Icons.settings),
          label: const Text('Paramètres serveur'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_forever),
          label: const Text('Supprimer mon compte'),
        ),
      ],
    );
  }
}
