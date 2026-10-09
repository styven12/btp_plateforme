import 'package:flutter/material.dart';

class AppColors {
  // COULEURS PRINCIPALES
  static const primary = Color(0xFFFF6B00); // Orange BTP - Actions principales
  static const secondary = Color(0xFF0A1931); // Bleu nuit - Client / MO
  static const success = Color(0xFF2E7D32); // Vert - Technicien / Validé

  // BACKGROUNDS
  static const background = Color(0xFFF8F9FA);
  static const white = Colors.white;
  static const cardLight = Color(0xFFF1F3F5);

  // TEXTE
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFF6C757D);
  static const textLight = Color(0xFFADB5BD);

  // ETATS
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);
  static const info = Color(0xFF1976D2);

  // SPECIFIQUE BTP
  static const fondation = Color(0xFF795548); // Marron
  static const elevation = Color(0xFF607D8B); // Gris béton

  // GRADIENT
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}