import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/payment_flow.dart';
import 'demande_detail_screen.dart';

/// Liste des demandes. Utilisateur : les siennes. Admin (adminMode) : toutes.
class DemandesTab extends StatefulWidget {
  final bool adminMode;
  const DemandesTab({super.key, this.adminMode = false});

  @override
  State<DemandesTab> createState() => _DemandesTabState();
}

class _DemandesTabState extends State<DemandesTab> {
  late Future<List<Demande>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthState>().backend.demandes();
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<AuthState>().backend.demandes());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _open(Demande d) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DemandeDetailScreen(demandeId: d.id, adminMode: widget.adminMode),
    ));
    if (mounted) _reload();
  }

  Future<void> _pay(Demande d) async {
    await runPaymentFlow(context, d);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Demande>>(
      future: _future,
      onRetry: _reload,
      builder: (context, demandes) {
        return RefreshIndicator(
          onRefresh: _reload,
          child: demandes.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Aucune demande pour le moment')),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: demandes.length,
                  itemBuilder: (context, i) {
                    final d = demandes[i];
                    return Card(
                      child: InkWell(
                        onTap: () => _open(d),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('#${d.id} · ${d.service.nom}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                  StatusChip(d.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${fmtMoney(d.montant)} · ${fmtDate(d.dateCreation)}'),
                              if (d.responsable != null) Text('Responsable : ${d.responsable!.nom}'),
                              if (widget.adminMode) Text('Compte wallet : #${d.userId}'),
                              if (d.enAttentePaiement && d.derniereErreurPaiement != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Dernier échec (${d.tentativesPaiement} tentative(s)) : ${d.derniereErreurPaiement}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              if (d.enAttentePaiement && !widget.adminMode) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: () => _pay(d),
                                    icon: const Icon(Icons.payment),
                                    label: Text(d.tentativesPaiement > 0 ? 'Réessayer le paiement' : 'Payer'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
