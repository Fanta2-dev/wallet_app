import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/payment_flow.dart';

class _DetailData {
  final Demande demande;
  final List<Tache> taches;
  _DetailData(this.demande, this.taches);
}

/// Détail d'une demande : infos, paiement, tâches (ressource + spécialité + délai + statut).
/// Mode admin : ajout de tâches, changement de statut des tâches et de la demande.
class DemandeDetailScreen extends StatefulWidget {
  final int demandeId;
  final bool adminMode;
  const DemandeDetailScreen({super.key, required this.demandeId, this.adminMode = false});

  @override
  State<DemandeDetailScreen> createState() => _DemandeDetailScreenState();
}

class _DemandeDetailScreenState extends State<DemandeDetailScreen> {
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final b = context.read<AuthState>().backend;
    final r = await Future.wait([b.demande(widget.demandeId), b.taches(widget.demandeId)]);
    return _DetailData(r[0] as Demande, r[1] as List<Tache>);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _addTask(Demande d) async {
    final b = context.read<AuthState>().backend;
    List<Ressource> ressources;
    try {
      ressources = await b.ressources();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (ressources.isEmpty) {
      showError(context, 'Créez d\'abord une ressource (onglet Admin > Ressources).');
      return;
    }

    final titre = TextEditingController();
    Ressource? ressource = ressources.first;
    DateTime delai = DateTime.now().add(const Duration(days: 7));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nouvelle tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titre,
                  decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Ressource>(
                  value: ressource,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ressource affectée', border: OutlineInputBorder()),
                  items: [
                    for (final r in ressources)
                      DropdownMenuItem(value: r, child: Text('${r.nom} — ${r.specialite}')),
                  ],
                  onChanged: (v) => setState(() => ressource = v),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('Délai : ${fmtDate(delai)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: delai,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => delai = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (titre.text.trim().isEmpty || ressource == null) {
      showError(context, 'Le titre est obligatoire');
      return;
    }
    try {
      await b.createTache(d.id, titre.text.trim(), ressource!.id, toIsoDate(delai));
      await _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _setTaskStatus(Tache t, String status) async {
    try {
      await context.read<AuthState>().backend.updateTacheStatus(t.id, status);
      await _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _setDemandeStatus(Demande d, String status, String question) async {
    if (!await confirmDialog(context, 'Confirmation', question, danger: status == 'ANNULEE')) return;
    try {
      await context.read<AuthState>().backend.updateDemandeStatus(d.id, status);
      await _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Demande #${widget.demandeId}')),
      body: LoadView<_DetailData>(
        future: _future,
        onRetry: _reload,
        builder: (context, data) {
          final d = data.demande;
          final canPlan = widget.adminMode && (d.status == 'PAYEE' || d.status == 'EN_COURS');
          return Scaffold(
            floatingActionButton: canPlan
                ? FloatingActionButton.extended(
                    onPressed: () => _addTask(d),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Ajouter une tâche'),
                  )
                : null,
            body: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(d.service.nom,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            ),
                            StatusChip(d.status),
                          ]),
                          const SizedBox(height: 8),
                          Text('Montant : ${fmtMoney(d.montant)}'),
                          Text('Créée le : ${fmtDateTime(d.dateCreation)}'),
                          if (d.datePaiement != null) Text('Payée le : ${fmtDateTime(d.datePaiement)}'),
                          if (d.responsable != null) Text('Responsable : ${d.responsable!.nom} (${d.responsable!.email})'),
                          if (d.enAttentePaiement && d.derniereErreurPaiement != null) ...[
                            const SizedBox(height: 8),
                            Text('Dernier échec : ${d.derniereErreurPaiement}',
                                style: const TextStyle(color: Colors.orange)),
                          ],
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (d.enAttentePaiement && !widget.adminMode)
                              FilledButton.icon(
                                icon: const Icon(Icons.payment),
                                label: Text(d.tentativesPaiement > 0 ? 'Réessayer le paiement' : 'Payer'),
                                onPressed: () async {
                                  await runPaymentFlow(context, d);
                                  if (mounted) _reload();
                                },
                              ),
                            if (d.enAttentePaiement)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Annuler la demande'),
                                onPressed: () => _setDemandeStatus(
                                    d, 'ANNULEE', 'Annuler la demande n°${d.id} ? Elle n\'a pas été payée.'),
                              ),
                            if (widget.adminMode && d.status == 'PAYEE')
                              OutlinedButton(
                                onPressed: () => _setDemandeStatus(d, 'EN_COURS', 'Démarrer la prestation ?'),
                                child: const Text('Démarrer'),
                              ),
                            if (widget.adminMode && d.status == 'EN_COURS')
                              OutlinedButton(
                                onPressed: () => _setDemandeStatus(d, 'TERMINEE', 'Marquer la prestation comme terminée ?'),
                                child: const Text('Terminer'),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tâches et ressources affectées', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (data.taches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(d.enAttentePaiement
                          ? 'Les tâches seront planifiées une fois la demande payée.'
                          : 'Aucune tâche planifiée pour le moment.'),
                    ),
                  for (final t in data.taches)
                    Card(
                      child: ListTile(
                        leading: Icon(t.enRetard ? Icons.warning_amber_rounded : Icons.task_alt,
                            color: t.enRetard ? Colors.red : null),
                        title: Text(t.titre),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.ressource.nom} · ${t.ressource.specialite}'),
                            Text('Délai : ${fmtDate(t.delai)}${t.enRetard ? '  (EN RETARD)' : ''}',
                                style: TextStyle(color: t.enRetard ? Colors.red : null)),
                            const SizedBox(height: 4),
                            Align(alignment: Alignment.centerLeft, child: StatusChip(t.status)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: widget.adminMode
                            ? PopupMenuButton<String>(
                                onSelected: (s) => _setTaskStatus(t, s),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'A_FAIRE', child: Text('À faire')),
                                  PopupMenuItem(value: 'EN_COURS', child: Text('En cours')),
                                  PopupMenuItem(value: 'TERMINEE', child: Text('Terminée')),
                                ],
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
