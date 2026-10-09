import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';

class AccountRegistrationPage extends StatefulWidget {
  const AccountRegistrationPage({required this.role, super.key});

  final String role;

  @override
  State<AccountRegistrationPage> createState() =>
      _AccountRegistrationPageState();
}

class _AccountRegistrationPageState extends State<AccountRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _companyController = TextEditingController();
  final _rccmController = TextEditingController();
  final _tradeController = TextEditingController();
  int _experience = 2;
  bool _loading = false;
  bool _obscurePassword = true;

  String get _roleName => switch (widget.role) {
    'mo' => 'Client / maître d’ouvrage',
    'entrepreneur' => 'Entrepreneur',
    _ => 'Technicien',
  };

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.instance.post(
        '/auth/register',
        body: {
          'fullName': _nameController.text.trim(),
          'telephone': _phoneController.text.trim(),
          'password': _passwordController.text,
          'role': widget.role,
          'city': _cityController.text.trim(),
          if (widget.role == 'entrepreneur') ...{
            'companyName': _companyController.text.trim(),
            'rccm': _rccmController.text.trim().toUpperCase(),
          },
          if (widget.role == 'technicien') ...{
            'trade': _tradeController.text.trim(),
            'experienceYears': _experience,
          },
        },
      );
      await ApiService.instance.saveToken(
        result['token'] as String,
        role: widget.role,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard/${widget.role}',
        (route) => false,
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _companyController.dispose();
    _rccmController.dispose();
    _tradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.role == 'mo'
        ? const Color(0xFF0A1931)
        : widget.role == 'technicien'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFFF6B00);

    return Scaffold(
      appBar: AppBar(title: Text('Créer un compte $_roleName')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _roleName,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vos informations sont enregistrées de façon sécurisée.',
              ),
              const SizedBox(height: 24),
              _field(_nameController, 'Nom complet', Icons.person_outline),
              const SizedBox(height: 16),
              _field(
                _phoneController,
                'Téléphone',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final normalized = (value ?? '').replaceAll(
                    RegExp(r'\D'),
                    '',
                  );
                  return normalized.length < 8
                      ? 'Numéro de téléphone invalide'
                      : null;
                },
              ),
              if (widget.role == 'mo') ...[
                const SizedBox(height: 16),
                _field(
                  _cityController,
                  'Ville / quartier',
                  Icons.location_on_outlined,
                ),
              ],
              if (widget.role == 'entrepreneur') ...[
                const SizedBox(height: 16),
                _field(
                  _companyController,
                  'Nom de l’entreprise',
                  Icons.apartment,
                ),
                const SizedBox(height: 16),
                _field(
                  _rccmController,
                  'Numéro RCCM',
                  Icons.badge_outlined,
                  validator: (value) =>
                      (value == null || value.trim().length < 5)
                      ? 'Numéro RCCM invalide'
                      : null,
                ),
                const SizedBox(height: 16),
                _field(_cityController, 'Ville', Icons.location_on_outlined),
              ],
              if (widget.role == 'technicien') ...[
                const SizedBox(height: 16),
                _field(
                  _tradeController,
                  'Métier (maçon, électricien…)',
                  Icons.handyman,
                ),
                const SizedBox(height: 8),
                Text('Expérience : $_experience ans'),
                Slider(
                  value: _experience.toDouble(),
                  min: 0,
                  max: 40,
                  divisions: 40,
                  label: '$_experience ans',
                  onChanged: (value) =>
                      setState(() => _experience = value.round()),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe (8 caractères minimum)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').length < 8
                    ? 'Utilisez au moins 8 caractères'
                    : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer mon compte'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Déjà inscrit ? Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (value) => (value == null || value.trim().isEmpty)
              ? '$label obligatoire'
              : null,
    );
  }
}
