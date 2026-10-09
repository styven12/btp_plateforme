import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import 'app_navigation_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  int _projectCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/auth/me'),
        ApiService.instance.get('/projects'),
      ]);
      if (!mounted) return;
      _user = results.first['user'] as Map<String, dynamic>;
      _projectCount = (results.last['projects'] as List? ?? const []).length;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.clearToken();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  String _roleLabel(String role) => switch (role) {
    'mo' => 'Maître d’ouvrage',
    'technicien' => 'Technicien',
    _ => 'Entrepreneur',
  };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final role = _user?['role'] as String? ?? 'entrepreneur';
    final fullName = _user?['fullName'] as String? ?? 'Votre profil';
    final company = _user?['companyName'] as String?;
    final city = _user?['city'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ProfileError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 116,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0A66C2), Color(0xFF70B5F9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(16),
                          child: const Icon(
                            Icons.engineering_outlined,
                            color: Colors.white70,
                            size: 38,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Transform.translate(
                            offset: const Offset(0, -34),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 34,
                                    backgroundColor: const Color(0xFFE8F2FC),
                                    foregroundColor: const Color(0xFF0A66C2),
                                    child: Text(
                                      _initials(fullName),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  company ?? _roleLabel(role),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (city != null && city.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    city,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Text(
                                  _roleLabel(role),
                                  style: const TextStyle(
                                    color: Color(0xFF0A66C2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations professionnelles',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ProfileItem(
                            icon: Icons.phone_outlined,
                            label: 'Téléphone',
                            value: _user?['telephone'] as String? ?? '—',
                          ),
                          if (company != null)
                            _ProfileItem(
                              icon: Icons.business_outlined,
                              label: 'Entreprise',
                              value: company,
                            ),
                          if (_user?['rccm'] != null)
                            _ProfileItem(
                              icon: Icons.badge_outlined,
                              label: 'RCCM',
                              value: _user!['rccm'] as String,
                            ),
                          if (_user?['trade'] != null)
                            _ProfileItem(
                              icon: Icons.handyman_outlined,
                              label: 'Métier',
                              value: _user!['trade'] as String,
                            ),
                          if (_user?['experienceYears'] != null)
                            _ProfileItem(
                              icon: Icons.workspace_premium_outlined,
                              label: 'Expérience',
                              value: '${_user!['experienceYears']} ans',
                            ),
                          _ProfileItem(
                            icon: Icons.location_on_outlined,
                            label: 'Ville',
                            value: city ?? 'Non renseignée',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F2FC),
                        foregroundColor: Color(0xFF0A66C2),
                        child: Icon(Icons.construction_outlined),
                      ),
                      title: const Text('Chantiers associés'),
                      subtitle: const Text('Projets auxquels vous participez'),
                      trailing: Text(
                        '$_projectCount',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF0A66C2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AppNavigationBar(role: role, selectedIndex: 2),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0A66C2)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
