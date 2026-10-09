import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import 'app_navigation_bar.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  List<Map<String, dynamic>> _professionals = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  bool _loading = true;
  String? _error;
  String _role = 'mo';
  String _filter = 'entrepreneur';
  int _tab = 0;

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
        ApiService.instance.get('/professionals'),
        ApiService.instance.get('/work-requests'),
      ]);
      if (!mounted) return;
      _role = (results.first['user'] as Map<String, dynamic>)['role'] as String;
      _professionals = List<Map<String, dynamic>>.from(
        results[1]['professionals'] as List? ?? const [],
      );
      _incoming = List<Map<String, dynamic>>.from(
        results[2]['incoming'] as List? ?? const [],
      );
      _outgoing = List<Map<String, dynamic>>.from(
        results[2]['outgoing'] as List? ?? const [],
      );
      if (_filter == 'entrepreneur' && _role != 'mo') {
        _filter = _role == 'technicien' ? 'entrepreneur' : 'mo';
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> professional) async {
    final request = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _NewWorkRequestDialog(),
    );
    if (request == null) return;
    try {
      await ApiService.instance.post(
        '/work-requests',
        body: {
          'recipientId': professional['id'],
          'projectName': request['projectName'],
          'message': request['message'],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande envoyée à ${professional['fullName']}.'),
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

  Future<void> _answerRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    try {
      await ApiService.instance.patch(
        '/work-requests/${request['id']}',
        body: {'status': status},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted' ? 'Demande acceptée.' : 'Demande refusée.',
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

  String _roleLabel(String role) => switch (role) {
    'mo' => 'Client',
    'technicien' => 'Technicien',
    _ => 'Entrepreneur',
  };

  IconData _roleIcon(String role) => switch (role) {
    'mo' => Icons.home_work_outlined,
    'technicien' => Icons.engineering_outlined,
    _ => Icons.apartment_outlined,
  };

  List<Map<String, dynamic>> get _visibleProfessionals => _filter == 'all'
      ? _professionals
      : _professionals.where((person) => person['role'] == _filter).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Réseau professionnel'),
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _NetworkError(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A66C2), Color(0xFF70B5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        size: 34,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _role == 'mo'
                            ? 'Trouvez le bon partenaire pour votre prochain chantier.'
                            : 'Développez votre réseau et découvrez de nouvelles opportunités.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Consultez les profils et envoyez une proposition de travail.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.people_outline),
                      label: Text('Découvrir'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Badge(
                        label: Text(
                          '${_incoming.where((item) => item['status'] == 'pending').length}',
                        ),
                        isLabelVisible: _incoming.any(
                          (item) => item['status'] == 'pending',
                        ),
                        child: const Icon(Icons.inbox_outlined),
                      ),
                      label: const Text('Reçues'),
                    ),
                    const ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.outbox_outlined),
                      label: Text('Envoyées'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) {
                    setState(() => _tab = selection.first);
                  },
                ),
                if (_tab == 0) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Explorer les intervenants',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'Tous'),
                        _filterChip('entrepreneur', 'Entrepreneurs'),
                        _filterChip('mo', 'Clients'),
                        _filterChip('technicien', 'Techniciens'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_visibleProfessionals.isEmpty)
                    const _EmptyNetwork(
                      message: 'Aucun profil trouvé dans cette catégorie.',
                    ),
                  ..._visibleProfessionals.map(
                    (person) => _professionalCard(person),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  Text(
                    _tab == 1 ? 'Demandes reçues' : 'Demandes envoyées',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...(_tab == 1 ? _incoming : _outgoing).map(
                    (request) => _requestCard(request, incoming: _tab == 1),
                  ),
                  if ((_tab == 1 ? _incoming : _outgoing).isEmpty)
                    _EmptyNetwork(
                      message: _tab == 1
                          ? 'Vous n’avez pas encore reçu de demande.'
                          : 'Vous n’avez pas encore envoyé de demande.',
                    ),
                ],
              ],
            ),
          ),
    bottomNavigationBar: AppNavigationBar(role: _role, selectedIndex: 1),
  );

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  Widget _professionalCard(Map<String, dynamic> person) {
    final name = person['fullName'] as String? ?? 'Intervenant';
    final role = person['role'] as String? ?? 'entrepreneur';
    final subtitle =
        person['companyName'] as String? ??
        person['trade'] as String? ??
        _roleLabel(role);
    final average = (person['averageRating'] as num?)?.toDouble();
    final existingRequest = _outgoing.cast<Map<String, dynamic>?>().firstWhere(
      (request) =>
          request?['recipientId'] == person['id'] &&
          request?['status'] == 'pending',
      orElse: () => null,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFE8F2FC),
                  foregroundColor: const Color(0xFF0A66C2),
                  child: Icon(_roleIcon(role)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (person['city'] is String &&
                          (person['city'] as String).isNotEmpty)
                        Text(
                          person['city'] as String,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                _RoleBadge(label: _roleLabel(role)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Stat(
                  icon: Icons.construction_outlined,
                  label: '${person['projectCount'] ?? 0} projets',
                ),
                if (average != null)
                  _Stat(
                    icon: Icons.star,
                    label: '${average.toStringAsFixed(1)} / 5',
                    color: const Color(0xFFB77B00),
                  )
                else
                  const _Stat(
                    icon: Icons.star_outline,
                    label: 'Pas encore noté',
                  ),
                if (role == 'entrepreneur')
                  _Stat(
                    icon: Icons.groups_outlined,
                    label: '${person['employeeCount'] ?? 0} techniciens',
                  ),
                if (role == 'technicien' && person['experienceYears'] != null)
                  _Stat(
                    icon: Icons.workspace_premium_outlined,
                    label: '${person['experienceYears']} ans d’expérience',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: existingRequest == null
                    ? () => _sendRequest(person)
                    : null,
                icon: Icon(
                  existingRequest == null
                      ? Icons.send_outlined
                      : Icons.hourglass_top,
                ),
                label: Text(
                  existingRequest == null
                      ? 'Proposer un nouveau travail'
                      : 'Demande en attente',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request, {required bool incoming}) {
    final personName = incoming
        ? request['senderName'] as String? ?? 'Intervenant'
        : request['recipientName'] as String? ?? 'Intervenant';
    final personRole = incoming
        ? request['senderRole'] as String? ?? 'entrepreneur'
        : request['recipientRole'] as String? ?? 'entrepreneur';
    final status = request['status'] as String? ?? 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE8F2FC),
                  foregroundColor: const Color(0xFF0A66C2),
                  child: Icon(_roleIcon(personRole)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_roleLabel(personRole)),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 24),
            Text(
              request['projectName'] as String? ?? 'Nouveau travail',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (request['message'] is String &&
                (request['message'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request['message'] as String),
            ],
            if (incoming && status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _answerRequest(request, 'rejected'),
                    child: const Text('Refuser'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _answerRequest(request, 'accepted'),
                    child: const Text('Accepter'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewWorkRequestDialog extends StatefulWidget {
  const _NewWorkRequestDialog();

  @override
  State<_NewWorkRequestDialog> createState() => _NewWorkRequestDialogState();
}

class _NewWorkRequestDialogState extends State<_NewWorkRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _projectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _projectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Proposer un nouveau travail'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _projectController,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Nom du projet ou du travail',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Saisissez au moins 3 caractères.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Détails (facultatif)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, {
              'projectName': _projectController.text.trim(),
              'message': _messageController.text.trim(),
            });
          }
        },
        child: const Text('Envoyer'),
      ),
    ],
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F2FC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF0A66C2),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('Acceptée', const Color(0xFF188038)),
      'rejected' => ('Refusée', const Color(0xFFB3261E)),
      _ => ('En attente', const Color(0xFF9A6700)),
    };
    return _RoleBadge(label: label).copyWithColor(color);
  }
}

extension on _RoleBadge {
  Widget copyWithColor(Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF5F6368),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 13)),
    ],
  );
}

class _EmptyNetwork extends StatelessWidget {
  const _EmptyNetwork({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 42, color: Color(0xFF0A66C2)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _NetworkError extends StatelessWidget {
  const _NetworkError({required this.message, required this.onRetry});

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
