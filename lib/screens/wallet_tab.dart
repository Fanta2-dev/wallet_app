import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';

class _WalletData {
  final double solde;
  final List<WalletTx> txs;
  _WalletData(this.solde, this.txs);
}

class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  late Future<_WalletData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WalletData> _load() async {
    final b = context.read<AuthState>().backend;
    final results = await Future.wait([b.balance(), b.transactions()]);
    return _WalletData(results[0] as double, results[1] as List<WalletTx>);
  }

  // ✅ MODIFICATION ICI : on crée le Future AVANT setState()
  Future<void> _reload() async {
    final newFuture = _load();
    setState(() {
      _future = newFuture;
    });
    try {
      await newFuture;
    } catch (_) {}
  }

  Future<void> _deposit() async {
    final amount = await askAmount(context, title: 'Déposer de l\'argent', confirm: 'Déposer');
    if (amount == null) return;
    try {
      await context.read<AuthState>().backend.deposit(amount);
      if (mounted) showInfo(context, 'Dépôt de ${fmtMoney(amount)} effectué');
      await _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _withdraw() async {
    final amount = await askAmount(context, title: 'Retirer de l\'argent', confirm: 'Continuer');
    if (amount == null || !mounted) return;
    final pin = await askPin(context, title: 'PIN pour retirer ${fmtMoney(amount)}');
    if (pin == null) return;
    try {
      await context.read<AuthState>().backend.withdraw(amount, pin);
      if (mounted) showInfo(context, 'Retrait de ${fmtMoney(amount)} effectué');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    return LoadView<_WalletData>(
      future: _future,
      onRetry: _reload,
      builder: (context, data) {
        final scheme = Theme.of(context).colorScheme;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF635BFF).withAlpha(45),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bonjour ${user?.fullName ?? ''} 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Solde disponible',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmtMoney(data.solde),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF635BFF),
                            ),
                            onPressed: _deposit,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Déposer'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: _withdraw,
                            icon: const Icon(Icons.arrow_upward_rounded),
                            label: const Text('Retirer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Activité récente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (data.txs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aucune transaction pour le moment')),
                ),
              for (final t in data.txs) _TxTile(tx: t),
            ],
          ),
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTx tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final credit = tx.type == 'DEPOT';
    final ok = tx.status == 'SUCCESS';
    final icon = switch (tx.type) {
      'DEPOT' => Icons.south_west,
      'RETRAIT' => Icons.north_east,
      _ => Icons.shopping_bag_outlined,
    };
    final sign = !ok ? '' : (credit ? '+' : '-');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (ok ? (credit ? Colors.green : Colors.indigo) : Colors.orange).withAlpha(40),
          child: Icon(icon, color: ok ? (credit ? Colors.green : Colors.indigo) : Colors.orange),
        ),
        title: Text(tx.description.isEmpty ? tx.type : tx.description),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [Text(fmtDateTime(tx.createdAt)), const SizedBox(width: 8), StatusChip(tx.status)]),
        ),
        trailing: Text('$sign${fmtMoney(tx.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: !ok ? Colors.grey : (credit ? Colors.green : null))),
      ),
    );
  }
}