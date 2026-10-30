import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import 'demandes_tab.dart';

/// Espace administrateur : toutes les demandes, catalogue, responsables, ressources, utilisateurs
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: const [
          Material(
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Demandes'),
                Tab(text: 'Services'),
                Tab(text: 'Responsables'),
                Tab(text: 'Ressources'),
                Tab(text: 'Utilisateurs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                DemandesTab(adminMode: true),
                _ServicesAdmin(),
                _ResponsablesAdmin(),
                _RessourcesAdmin(),
                _UsersAdmin(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette commun : liste + bouton d'ajout
class _CrudList<T> extends StatefulWidget {
  final Future<List<T>> Function(AuthState auth) loader;
  final Widget Function(T item) tile;
  final Future<void> Function(BuildContext context, AuthState auth)? onAdd;
  final String addLabel;

  const _CrudList({
    super.key,
    required this.loader,
    required this.tile,
    this.onAdd,
    this.addLabel = 'Ajouter',
  });

  @override
  State<_CrudList<T>> createState() => _CrudListState<T>();
}

class _CrudListState<T> extends State<_CrudList<T>> with AutomaticKeepAliveClientMixin {
  late Future<List<T>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(context.read<AuthState>());
  }

  Future<void> _reload() async {
    setState(() => _future = widget.loader(context.read<AuthState>()));
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await widget.onAdd!(context, context.read<AuthState>());
                if (mounted) _reload();
              },
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
      body: LoadView<List<T>>(
        future: _future,
        onRetry: _reload,
        builder: (context, items) => RefreshIndicator(
          onRefresh: _reload,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 120), Center(child: Text('Aucun élément'))],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [for (final it in items) widget.tile(it)],
                ),
        ),
      ),
    );
  }
}

class _ServicesAdmin extends StatelessWidget {
  const _ServicesAdmin();

  @override
  Widget build(BuildContext context) {
    return _CrudList<ServiceOffre>(
      loader: (a) => a.backend.services(),
      tile: (s) => Card(
        child: ListTile(
          leading: const Icon(Icons.design_services),
          title: Text(s.nom),
          subtitle: Text(s.description),
          trailing: Text(fmtMoney(s.prix), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      addLabel: 'Service',
      onAdd: (ctx, auth) async {
        final v = await askFields(ctx,
            title: 'Nouveau service',
            labels: ['Nom', 'Description', 'Prix (FCFA)'],
            types: [TextInputType.text, TextInputType.text, TextInputType.number]);
        if (v == null) return;
        final prix = double.tryParse(v[2]);
        if (v[0].isEmpty || prix == null) {
          if (ctx.mounted) showError(ctx, 'Nom et prix valides obligatoires');
          return;
        }
        try {
          await auth.backend.createService(v[0], v[1], prix);
        } catch (e) {
          if (ctx.mounted) showError(ctx, e);
        }
      },
    );
  }
}

class _ResponsablesAdmin extends StatelessWidget {
  const _ResponsablesAdmin();

  @override
  Widget build(BuildContext context) {
    return _CrudList<Responsable>(
      loader: (a) => a.backend.responsables(),
      tile: (r) => Card(
        child: ListTile(
          leading: const Icon(Icons.supervisor_account),
          title: Text(r.nom),
          subtitle: Text(r.email),
        ),
      ),
      addLabel: 'Responsable',
      onAdd: (ctx, auth) async {
        final v = await askFields(ctx,
            title: 'Nouveau responsable',
            labels: ['Nom', 'Email'],
            types: [TextInputType.name, TextInputType.emailAddress]);
        if (v == null) return;
        if (v[0].isEmpty) {
          if (ctx.mounted) showError(ctx, 'Le nom est obligatoire');
          return;
        }
        try {
          await auth.backend.createResponsable(v[0], v[1]);
        } catch (e) {
          if (ctx.mounted) showError(ctx, e);
        }
      },
    );
  }
}

class _RessourcesAdmin extends StatelessWidget {
  const _RessourcesAdmin();

  @override
  Widget build(BuildContext context) {
    return _CrudList<Ressource>(
      loader: (a) => a.backend.ressources(),
      tile: (r) => Card(
        child: ListTile(
          leading: const Icon(Icons.engineering),
          title: Text(r.nom),
          subtitle: Text('Spécialité : ${r.specialite}'),
        ),
      ),
      addLabel: 'Ressource',
      onAdd: (ctx, auth) async {
        final v = await askFields(ctx, title: 'Nouvelle ressource', labels: ['Nom', 'Spécialité']);
        if (v == null) return;
        if (v[0].isEmpty || v[1].isEmpty) {
          if (ctx.mounted) showError(ctx, 'Nom et spécialité obligatoires');
          return;
        }
        try {
          await auth.backend.createRessource(v[0], v[1]);
        } catch (e) {
          if (ctx.mounted) showError(ctx, e);
        }
      },
    );
  }
}

class _UsersAdmin extends StatefulWidget {
  const _UsersAdmin();

  @override
  State<_UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<_UsersAdmin> {
  final _key = GlobalKey<_CrudListState<AppUser>>();

  Future<void> _delete(AppUser u) async {
    final auth = context.read<AuthState>();
    if (u.id == auth.user?.id) {
      showError(context, 'Utilisez « Supprimer mon compte » depuis le profil.');
      return;
    }
    final ok = await confirmDialog(context, 'Supprimer l\'utilisateur',
        'Supprimer ${u.fullName} (${u.phone}) ? Action définitive.',
        confirm: 'Supprimer', danger: true);
    if (!ok) return;
    try {
      await auth.backend.deleteUser(u.id);
      await _key.currentState?._reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CrudList<AppUser>(
      key: _key,
      loader: (a) => a.backend.users(),
      tile: (u) => Card(
        child: ListTile(
          leading: Icon(u.isAdmin ? Icons.shield : Icons.person),
          title: Text(u.fullName),
          subtitle: Text('${u.phone}\n${u.email}'),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmtMoney(u.solde), style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(u),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
