import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/api_service.dart';

class PartagerCodePage extends StatefulWidget {
  const PartagerCodePage({super.key});

  @override
  State<PartagerCodePage> createState() => _PartagerCodePageState();
}

class _PartagerCodePageState extends State<PartagerCodePage> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.instance.get('/projects');
      if (!mounted) return;
      _projects = List<Map<String, dynamic>>.from(
        result['projects'] as List? ?? const [],
      );
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Code copié.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partager les codes chantier')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _projects.isEmpty
        ? const Center(
            child: Text('Créez d’abord un chantier pour obtenir son code.'),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                final code = project['code'] as String? ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(project['name'] as String? ?? 'Chantier'),
                    subtitle: Text('Code d’accès : $code'),
                    trailing: IconButton(
                      tooltip: 'Copier le code',
                      onPressed: () => _copy(code),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
