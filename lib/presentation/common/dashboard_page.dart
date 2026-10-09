import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import 'app_navigation_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.role, super.key});

  final String role;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  String get _title => switch (widget.role) {
    'mo' => 'Espace client',
    'technicien' => 'Espace technicien',
    _ => 'Espace entrepreneur',
  };

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
        ApiService.instance.get('/projects'),
        if (widget.role == 'entrepreneur')
          ApiService.instance.get('/projects/requests'),
      ]);
      if (!mounted) return;
      _projects = List<Map<String, dynamic>>.from(
        results.first['projects'] as List? ?? const [],
      );
      _requests = widget.role == 'entrepreneur'
          ? List<Map<String, dynamic>>.from(
              results[1]['requests'] as List? ?? const [],
            )
          : [];
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decideRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    try {
      await ApiService.instance.patch(
        '/projects/requests/${request['id']}',
        body: {'status': status},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Demande acceptée.' : 'Demande refusée.',
          ),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.clearToken();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.role == 'mo'
        ? const Color(0xFF0A1931)
        : widget.role == 'technicien'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFFF6B00);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
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
          ? _ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _WelcomeCard(role: widget.role, color: color),
                  const SizedBox(height: 24),
                  if (widget.role == 'entrepreneur') ...[
                    _SectionTitle(
                      title: 'Demandes à traiter',
                      count: _requests.length,
                    ),
                    if (_requests.isEmpty)
                      const _EmptyHint(text: 'Aucune demande en attente.'),
                    ..._requests.map(_requestCard),
                    const SizedBox(height: 20),
                  ],
                  _SectionTitle(
                    title: widget.role == 'mo'
                        ? 'Mes chantiers'
                        : widget.role == 'technicien'
                        ? 'Chantiers auxquels je participe'
                        : 'Mes projets',
                    count: _projects.length,
                  ),
                  if (_projects.isEmpty)
                    _EmptyProjects(role: widget.role, color: color),
                  ..._projects.map(_projectCard),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: AppNavigationBar(
        role: widget.role,
        selectedIndex: 0,
      ),
      floatingActionButton: widget.role == 'entrepreneur'
          ? FloatingActionButton.extended(
              backgroundColor: color,
              foregroundColor: Colors.white,
              onPressed: () async {
                final created = await Navigator.pushNamed(
                  context,
                  '/project/create',
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer un chantier'),
            )
          : FloatingActionButton.extended(
              backgroundColor: color,
              foregroundColor: Colors.white,
              onPressed: () async {
                final submitted = await Navigator.pushNamed(context, '/code');
                if (submitted == true) _load();
              },
              icon: const Icon(Icons.vpn_key),
              label: const Text('Saisir un code'),
            ),
    );
  }

  Widget _projectCard(Map<String, dynamic> project) {
    final progress = ((project['progress'] as num?)?.toDouble() ?? 0) / 100;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Navigator.pushNamed(context, '/project/detail', arguments: project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project['name'] as String? ?? 'Chantier',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${project['code']}  •  ${project['location'] ?? 'Lieu non précisé'}',
              ),
              if (widget.role == 'mo' && project['companyName'] != null)
                Text('Entreprise : ${project['companyName']}'),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text('${(progress * 100).round()} % d’avancement'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final isTechnician = request['role'] == 'technicien';
    final details = isTechnician
        ? '${request['trade'] ?? 'Technicien'} • ${request['experienceYears'] ?? 0} ans d’expérience'
        : 'Client / maître d’ouvrage';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['name'] as String? ?? 'Nouvelle demande',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('$details • ${request['projectName']} (${request['code']})'),
            Text(request['telephone'] as String? ?? ''),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _decideRequest(request, 'rejected'),
                  child: const Text('Refuser'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _decideRequest(request, 'approved'),
                  child: const Text('Accepter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(
            role == 'mo'
                ? Icons.home_work
                : role == 'entrepreneur'
                ? Icons.apartment
                : Icons.engineering,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            role == 'mo'
                ? 'Suivez votre chantier en toute transparence.'
                : role == 'entrepreneur'
                ? 'Gérez vos projets et les accès aux chantiers.'
                : 'Retrouvez les chantiers auxquels vous participez.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Chip(label: Text('$count')),
      ],
    ),
  );
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.construction_outlined, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            role == 'entrepreneur'
                ? 'Vous n’avez pas encore créé de chantier.'
                : 'Aucun chantier lié à votre compte pour le moment.',
            textAlign: TextAlign.center,
          ),
          if (role != 'entrepreneur')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Saisissez le code BTP fourni pour demander l’accès.',
              ),
            ),
        ],
      ),
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
