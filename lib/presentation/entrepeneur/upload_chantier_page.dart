import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/project_image.dart';

class UploadChantierPage extends StatefulWidget {
  const UploadChantierPage({super.key});

  @override
  State<UploadChantierPage> createState() => _UploadChantierPageState();
}

class _UploadChantierPageState extends State<UploadChantierPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageType;
  bool _pickingImage = false;
  double _progress = 0;
  bool _loading = false;

  Future<void> _submit(Map<String, dynamic> project) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? photoUrl;
      if (_imageBytes != null) {
        final result = await ApiService.instance.uploadProjectImage(
          projectId: '${project['id']}',
          bytes: _imageBytes!,
          filename: _imageName!,
          contentType: _imageType!,
        );
        photoUrl = result['url'] as String;
      }
      await ApiService.instance.post(
        '/projects/${project['id']}/journal',
        body: {
          'description': _descriptionController.text.trim(),
          'progress': _progress.round(),
          if (photoUrl != null) 'photoUrl': photoUrl,
        },
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

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) return;
      final prepared = await ProjectImage.prepareAsync(
        await image.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        _imageBytes = prepared.bytes;
        _imageName = prepared.fileName;
        _imageType = 'image/jpeg';
      });
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
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
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mise à jour du chantier')),
        body: const Center(child: Text('Chantier introuvable.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Publier une mise à jour')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              args['name'] as String? ?? 'Chantier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Travaux réalisés',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Décrivez les travaux réalisés'
                  : null,
            ),
            const SizedBox(height: 18),
            Text('Avancement : ${_progress.round()} %'),
            Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (value) => setState(() => _progress = value),
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickingImage ? null : _pickImage,
              icon: _pickingImage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_imageName ?? 'Choisir une photo (facultatif)'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading || _pickingImage ? null : () => _submit(args),
              icon: const Icon(Icons.publish),
              label: Text(_loading ? 'Envoi…' : 'Publier'),
            ),
          ],
        ),
      ),
    );
  }
}
