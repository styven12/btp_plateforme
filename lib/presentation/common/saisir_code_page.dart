import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/api_service.dart';

class SaisirCodePage extends StatefulWidget {
  const SaisirCodePage({super.key});

  @override
  State<SaisirCodePage> createState() => _SaisirCodePageState();
}

class _SaisirCodePageState extends State<SaisirCodePage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^BTP-[A-Z0-9]{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le code doit être au format BTP-XXXX.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.instance.post(
        '/projects/join',
        body: {'code': code},
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.hourglass_top,
            color: Color(0xFFFF6B00),
            size: 42,
          ),
          title: const Text('Demande envoyée'),
          content: Text(
            result['message'] as String? ?? 'En attente de validation.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rejoindre un chantier')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.vpn_key_rounded,
                size: 72,
                color: Color(0xFF0A1931),
              ),
              const SizedBox(height: 16),
              Text(
                'Saisissez le code du chantier',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre demande sera envoyée à l’entrepreneur pour validation.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  hintText: 'BTP-AB12',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Envoyer la demande'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
