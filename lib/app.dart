import 'package:flutter/material.dart';

import 'presentation/auth/choix_role_page.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/auth/register_entrepreneur_page.dart';
import 'presentation/auth/register_mo_page.dart';
import 'presentation/auth/register_technicien_page.dart';
import 'presentation/common/dashboard_page.dart';
import 'presentation/common/network_page.dart';
import 'presentation/common/profile_page.dart';
import 'presentation/common/projet_detail_page.dart';
import 'presentation/common/saisir_code_page.dart';
import 'presentation/entrepeneur/creer_projet_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BTP Platform',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A66C2)),
      scaffoldBackgroundColor: const Color(0xFFF3F2EF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF3F2EF),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    initialRoute: '/',
    routes: {
      '/': (_) => const ChoixRolePage(),
      '/login': (_) => const LoginPage(),
      '/register/mo': (_) => const RegisterMoPage(),
      '/register/entrepreneur': (_) => const RegisterEntrepreneurPage(),
      '/register/technicien': (_) => const RegisterTechnicienPage(),
      '/dashboard/mo': (_) => const DashboardPage(role: 'mo'),
      '/dashboard/entrepreneur': (_) =>
          const DashboardPage(role: 'entrepreneur'),
      '/dashboard/technicien': (_) => const DashboardPage(role: 'technicien'),
      '/code': (_) => const SaisirCodePage(),
      '/project/create': (_) => const CreerProjetPage(),
      '/project/detail': (_) => const ProjetDetailPage(),
      '/network': (_) => const NetworkPage(),
      '/profile': (_) => const ProfilePage(),
    },
  );
}
