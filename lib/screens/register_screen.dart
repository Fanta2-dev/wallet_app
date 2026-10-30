import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';

/// Inscription en 3 étapes : 1) identité  2) code OTP (simulé)  3) choix du PIN
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  bool _busy = false;
  OtpInfo? _otp;

  final _form1 = GlobalKey<FormState>();
  final _form3 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _code, _pin, _pin2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() async {
    if (!_form1.currentState!.validate()) return;
    await _run(() async {
      final otp = await context
          .read<AuthState>()
          .registerInit(_phone.text.trim(), _email.text.trim(), _name.text.trim());
      setState(() {
        _otp = otp;
        _step = 1;
      });
    });
  }

  Future<void> _verifyOtp() async {
    if (_code.text.length != 6) {
      showError(context, 'Le code OTP contient 6 chiffres');
      return;
    }
    await _run(() async {
      await context.read<AuthState>().verifyOtp(_phone.text.trim(), _code.text);
      setState(() => _step = 2);
    });
  }

  Future<void> _setPin() async {
    if (!_form3.currentState!.validate()) return;
    await _run(() async {
      // ouvre la session et revient à l'écran racine (Home)
      await context.read<AuthState>().finishRegistration(_pin.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Progress(step: _step),
              const SizedBox(height: 24),
              if (_step == 0) _stepIdentity(),
              if (_step == 1) _stepOtp(),
              if (_step == 2) _stepPin(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIdentity() {
    return Form(
      key: _form1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vos informations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nom complet', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: '+221770000001',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder()),
            validator: (v) =>
                RegExp(r'^\+?[0-9]{8,15}$').hasMatch((v ?? '').trim()) ? null : 'Numéro invalide (8 à 15 chiffres)',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Email invalide',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _sendOtp,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _busy ? const _Spinner() : const Text('Recevoir le code OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Validation du numéro et de l\'email', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OTP SIMULÉ (pas de vrai SMS dans ce projet)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_otp?.code ?? '',
                        style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _code.text = _otp?.code ?? ''),
                      child: const Text('Remplir'),
                    ),
                  ],
                ),
                Text('Valable ${_otp?.validiteMinutes ?? 5} minutes.', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: 'Code OTP', prefixIcon: Icon(Icons.sms), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _verifyOtp,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy ? const _Spinner() : const Text('Valider le code'),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = 0),
          child: const Text('Modifier mes informations'),
        ),
      ],
    );
  }

  Widget _stepPin() {
    return Form(
      key: _form3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choisissez votre PIN', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Il protège vos retraits et paiements. 4 à 6 chiffres, stocké haché (BCrypt).'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'PIN', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
            validator: (v) => RegExp(r'^\d{4,6}$').hasMatch(v ?? '') ? null : 'PIN : 4 à 6 chiffres',
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Confirmer le PIN', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
            validator: (v) => v == _pin.text ? null : 'Les PIN ne correspondent pas',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _setPin,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _busy ? const _Spinner() : const Text('Terminer l\'inscription'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
}

class _Progress extends StatelessWidget {
  final int step;
  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Infos', 'OTP', 'PIN'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= step
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: i <= step ? Theme.of(context).colorScheme.onPrimary : null, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
