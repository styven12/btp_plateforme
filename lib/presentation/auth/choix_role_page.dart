import 'package:flutter/material.dart';

import '../../widgets/role_card_widget.dart';

class ChoixRolePage extends StatelessWidget {
  const ChoixRolePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.handyman,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'BTP PLATFORM',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Construire en confiance',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Bienvenue',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez votre profil pour continuer.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          RoleCardWidget(
            icon: Icons.home_work_rounded,
            color: const Color(0xFF0A1931),
            title: 'Je suis Client',
            subtitle: 'Maître d’ouvrage — je fais construire',
            onTap: () => Navigator.pushNamed(context, '/register/mo'),
          ),
          const SizedBox(height: 12),
          RoleCardWidget(
            icon: Icons.apartment_rounded,
            color: const Color(0xFFFF6B00),
            title: 'Je suis Entrepreneur',
            subtitle: 'Entreprise enregistrée avec RCCM',
            badge: 'PRO',
            onTap: () => Navigator.pushNamed(context, '/register/entrepreneur'),
          ),
          const SizedBox(height: 12),
          RoleCardWidget(
            icon: Icons.engineering_rounded,
            color: const Color(0xFF2E7D32),
            title: 'Je suis Technicien',
            subtitle: 'Maçon, électricien, plombier…',
            onTap: () => Navigator.pushNamed(context, '/register/technicien'),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Déjà un compte ? Se connecter'),
            ),
          ),
        ],
      ),
    ),
  );
}
