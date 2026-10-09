import 'package:flutter/material.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.role,
    required this.selectedIndex,
    super.key,
  });

  final String role;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Réseau',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_circle_outlined),
        selectedIcon: Icon(Icons.account_circle),
        label: 'Profil',
      ),
    ],
    onDestinationSelected: (index) {
      if (index == selectedIndex) return;
      if (index == 1) {
        Navigator.pushNamed(context, '/network');
      } else if (index == 2) {
        Navigator.pushNamed(context, '/profile');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard/$role');
      }
    },
  );
}
