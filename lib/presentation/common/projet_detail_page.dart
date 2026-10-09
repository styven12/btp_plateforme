import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/project_image.dart';

class ProjetDetailPage extends StatefulWidget {
  const ProjetDetailPage({super.key});

  @override
  State<ProjetDetailPage> createState() => _ProjetDetailPageState();
}

class _ProjetDetailPageState extends State<ProjetDetailPage> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myReview;
  double? _averageRating;
  bool _loading = true;
  bool _isEntrepreneurOrTechnician = false;
  String? _error;
  String? _reviewError;

  @override
  void initState() {
    super.initState();
    _loadRoleAndJournal();
  }

  Future<void> _loadRoleAndJournal() async {
    final role = await ApiService.instance.savedRole;
    if (mounted) {
      setState(() {
        _isEntrepreneurOrTechnician =
            role == 'entrepreneur' || role == 'technicien';
      });
    }
    final project = ModalRoute.of(context)?.settings.arguments;
    await Future.wait([
      _loadJournal(),
      if (project is Map<String, dynamic>) _loadReviews(project),
    ]);
  }

  Future<void> _loadReviews(Map<String, dynamic> project) async {
    try {
      final result = await ApiService.instance.get(
        '/projects/${project['id']}/project-reviews',
      );
      if (!mounted) return;
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(
          result['reviews'] as List? ?? const [],
        );
        _myReview = result['myReview'] as Map<String, dynamic>?;
        _averageRating = (result['average'] as num?)?.toDouble();
        _reviewError = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _reviewError = error.message);
    }
  }

  Future<void> _loadJournal() async {
    final project = ModalRoute.of(context)?.settings.arguments;
    if (project is! Map<String, dynamic>) {
      setState(() {
        _error = 'Projet introuvable.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.get(
        '/projects/${project['id']}/journal',
      );
      if (!mounted) return;
      _entries = List<Map<String, dynamic>>.from(
        result['entries'] as List? ?? const [],
      );
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addJournal(Map<String, dynamic> project) async {
    final submission = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _JournalEntryDialog(
        initialProgress: (project['progress'] as num?)?.toDouble() ?? 0,
      ),
    );
    if (submission == null) return;
    try {
      final imageBytes = submission.remove('imageBytes') as Uint8List?;
      if (imageBytes != null) {
        final upload = await ApiService.instance.uploadProjectImage(
          projectId: '${project['id']}',
          bytes: imageBytes,
          filename: submission.remove('imageName') as String,
          contentType: submission.remove('imageType') as String,
        );
        submission['photoUrl'] = upload['url'] as String;
      }
      await ApiService.instance.post(
        '/projects/${project['id']}/journal',
        body: submission,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mise à jour enregistrée.')));
      await _loadJournal();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _leaveReview(Map<String, dynamic> project) async {
    final review = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (review == null) return;
    try {
      await ApiService.instance.post(
        '/projects/${project['id']}/project-reviews',
        body: review,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Merci pour votre avis.')));
        await _loadReviews(project);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeProject = ModalRoute.of(context)?.settings.arguments;
    if (routeProject is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail du chantier')),
        body: const Center(child: Text('Projet introuvable.')),
      );
    }
    final project = routeProject;
    final progress = ((project['progress'] as num?)?.toDouble() ?? 0) / 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du chantier')),
      body: RefreshIndicator(
        onRefresh: _loadJournal,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project['name'] as String? ?? 'Chantier',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Code : ${project['code']}'),
                    Text('Lieu : ${project['location'] ?? 'Non précisé'}'),
                    Text(
                      'Entreprise : ${project['companyName'] ?? project['entrepreneurName'] ?? '—'}',
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress, minHeight: 8),
                    const SizedBox(height: 6),
                    Text('Avancement : ${(progress * 100).round()} %'),
                    if (project['description'] != null &&
                        (project['description'] as String).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(project['description'] as String),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Avis sur le chantier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _ProjectReviews(
              reviews: _reviews,
              average: _averageRating,
              myReview: _myReview,
              error: _reviewError,
              onRetry: () => _loadReviews(project),
              onRate: () => _leaveReview(project),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Journal du chantier',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEntrepreneurOrTechnician)
                  IconButton.filledTonal(
                    tooltip: 'Ajouter une mise à jour',
                    onPressed: () => _addJournal(project),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: _loadJournal,
                child: const Text('Réessayer'),
              ),
            ],
            if (!_loading && _error == null && _entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucune mise à jour publiée.'),
              ),
            ..._entries.map(
              (entry) => Card(
                margin: const EdgeInsets.only(top: 8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.construction),
                      ),
                      title: Text(entry['description'] as String? ?? ''),
                      subtitle: Text(
                        '${entry['progress']} % • ${entry['authorName'] ?? 'Équipe chantier'}',
                      ),
                      isThreeLine: true,
                    ),
                    if (entry['photoUrl'] is String &&
                        (entry['photoUrl'] as String).isNotEmpty)
                      Image.network(
                        entry['photoUrl'] as String,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          final total = progress.expectedTotalBytes;
                          final value = total == null
                              ? null
                              : progress.cumulativeBytesLoaded / total;
                          return SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(value: value),
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 120,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined),
                              SizedBox(height: 6),
                              Text('Impossible de charger cette photo'),
                            ],
                          ),
                        ),
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

class _ProjectReviews extends StatelessWidget {
  const _ProjectReviews({
    required this.reviews,
    required this.average,
    required this.myReview,
    required this.error,
    required this.onRetry,
    required this.onRate,
  });

  final List<Map<String, dynamic>> reviews;
  final double? average;
  final Map<String, dynamic>? myReview;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB400)),
              const SizedBox(width: 6),
              Text(
                average == null
                    ? 'Pas encore noté'
                    : average!.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                'sur 5 • ${reviews.length} avis',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
          if (reviews.isEmpty && error == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Soyez le premier intervenant à noter ce chantier.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ...reviews.map((review) {
            final name = review['authorName'] as String? ?? 'Intervenant';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE8F2FC),
                foregroundColor: const Color(0xFF0A66C2),
                child: Text(name.trim().isEmpty ? 'I' : name.trim()[0]),
              ),
              title: Text(name),
              subtitle: Text(
                review['comment'] as String? ?? 'Aucun commentaire',
              ),
              trailing: Text(
                '${review['rating']} ★',
                style: const TextStyle(
                  color: Color(0xFFB77B00),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
          if (myReview != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Votre note : ${myReview!['rating']} / 5',
                style: const TextStyle(
                  color: Color(0xFF0A66C2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: error == null ? onRate : null,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Noter ce chantier'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _JournalEntryDialog extends StatefulWidget {
  const _JournalEntryDialog({required this.initialProgress});

  final double initialProgress;

  @override
  State<_JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<_JournalEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageType;
  bool _pickingImage = false;
  late double _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() {
        _imageBytes = null;
        _imageName = 'Préparation de la photo…';
        _imageType = 'image/jpeg';
      });
      final prepared = await ProjectImage.prepareAsync(
        await image.readAsBytes(),
      );
      if (mounted) {
        setState(() {
          _imageBytes = prepared.bytes;
          _imageName = prepared.fileName;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _imageName = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de choisir la photo : ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 80;
    final contentWidth = availableWidth.clamp(200.0, 400.0).toDouble();
    return AlertDialog(
      title: const Text('Ajouter une mise à jour'),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Travaux réalisés',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'La description est obligatoire'
                  : null,
            ),
            const SizedBox(height: 14),
            Text('Avancement : ${_progress.round()} %'),
            Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (value) => setState(() => _progress = value),
            ),
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 110,
                  width: contentWidth,
                  fit: BoxFit.cover,
                ),
              ),
            TextButton.icon(
              onPressed: _pickingImage ? null : _pickImage,
              icon: _pickingImage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_imageName ?? 'Ajouter une photo'),
            ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed:
              _pickingImage || (_imageName != null && _imageBytes == null)
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'description': _descriptionController.text.trim(),
                      'progress': _progress.round(),
                      if (_imageBytes != null) ...{
                        'imageBytes': _imageBytes,
                        'imageName': _imageName,
                        'imageType': _imageType,
                      },
                    });
                  }
                },
          child: Text(
            _pickingImage || (_imageName != null && _imageBytes == null)
                ? 'Préparation de la photo…'
                : 'Enregistrer',
          ),
        ),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Noter le chantier'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _rating,
          decoration: const InputDecoration(labelText: 'Note'),
          items: List.generate(5, (index) => index + 1)
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value / 5')),
              )
              .toList(),
          onChanged: (value) => setState(() => _rating = value ?? 5),
        ),
        TextField(
          controller: _commentController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Commentaire (facultatif)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'rating': _rating,
          'comment': _commentController.text.trim(),
        }),
        child: const Text('Envoyer'),
      ),
    ],
  );
}
