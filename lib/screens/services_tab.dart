import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/payment_flow.dart';

class _CatalogData {
  final List<ServiceOffre> services;
  final List<Responsable> responsables;
  _CatalogData(this.services, this.responsables);
}

/// Catalogue des services : l'utilisateur choisit un service + un responsable, la demande est créée
/// (EN_ATTENTE_PAIEMENT) puis il peut la payer immédiatement ou plus tard.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  late Future<_CatalogData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CatalogData> _load() async {
    final b = context.read<AuthState>().backend;
    final r = await Future.wait([b.services(), b.responsables()]);
    return _CatalogData(r[0] as List<ServiceOffre>, r[1] as List<Responsable>);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _order(ServiceOffre service, List<Responsable> responsables) async {
    if (responsables.isEmpty) {
      showError(context, 'Aucun responsable disponible : un administrateur doit en créer un.');
      return;
    }
    Responsable? chosen = responsables.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Commander : ${service.nom}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prix : ${fmtMoney(service.prix)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<Responsable>(
                value: chosen,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Responsable de la prestation', border: OutlineInputBorder()),
                items: [
                  for (final r in responsables) DropdownMenuItem(value: r, child: Text(r.nom)),
                ],
                onChanged: (v) => setState(() => chosen = v),
              ),
              const SizedBox(height: 12),
              const Text(
                'La demande sera créée « en attente de paiement ».',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer la demande')),
          ],
        ),
      ),
    );
    if (ok != true || chosen == null || !mounted) return;

    final auth = context.read<AuthState>();
    Demande demande;
    try {
      demande = await auth.backend.createDemande(service.id, chosen!.id);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;

    final payNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.receipt_long, size: 40),
        title: Text('Demande n°${demande.id} créée'),
        content: Text('Statut : en attente de paiement.\nMontant : ${fmtMoney(demande.montant)}.\n\n'
            'Voulez-vous payer maintenant avec votre wallet ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Payer maintenant')),
        ],
      ),
    );
    if (payNow == true && mounted) {
      await runPaymentFlow(context, demande);
    } else if (mounted) {
      showInfo(context, 'Retrouvez votre demande dans « Mes demandes ».');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<_CatalogData>(
      future: _future,
      onRetry: _reload,
      builder: (context, data) => RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Services', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Choisissez une prestation et commandez en quelques secondes.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (data.services.isEmpty) const Center(child: Text('Aucun service disponible')),
            for (final s in data.services)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.nom,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (s.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(s.description),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(fmtMoney(s.prix),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green.shade700)),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () => _order(s, data.responsables),
                            icon: const Icon(Icons.shopping_cart_outlined),
                            label: const Text('Commander'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
