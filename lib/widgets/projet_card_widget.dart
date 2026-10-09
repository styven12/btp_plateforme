import 'package:flutter/material.dart';

class ProjetCardWidget extends StatelessWidget {
  const ProjetCardWidget({required this.projet, this.onTap, super.key});

  final Map<String, dynamic> projet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress =
        ((projet['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projet['name'] as String? ?? 'Chantier',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${projet['code'] ?? ''} • ${projet['location'] ?? 'Lieu non précisé'}',
              ),
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
}
