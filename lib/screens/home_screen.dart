import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import 'admin_screen.dart';
import 'demandes_tab.dart';
import 'profile_tab.dart';
import 'services_tab.dart';
import 'wallet_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthState>().user?.isAdmin ?? false;

    final pages = <(String, IconData, Widget)>[
      ('Portefeuille', Icons.account_balance_wallet_outlined, const WalletTab()),
      ('Services', Icons.storefront_outlined, const ServicesTab()),
      ('Mes demandes', Icons.receipt_long_outlined, const DemandesTab()),
      if (isAdmin) ('Admin', Icons.admin_panel_settings_outlined, const AdminScreen()),
      ('Profil', Icons.person_outline, const ProfileTab()),
    ];
    final index = _index < pages.length ? _index : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(pages[index].$1),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (context.watch<AuthState>().user?.fullName ?? 'U').trim().isEmpty
                    ? 'U'
                    : context.watch<AuthState>().user!.fullName.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      // La page est reconstruite à chaque changement d'onglet : les données sont donc rechargées
      body: KeyedSubtree(key: ValueKey(index), child: pages[index].$3),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final p in pages) NavigationDestination(icon: Icon(p.$2), label: p.$1),
        ],
      ),
    );
  }
}
