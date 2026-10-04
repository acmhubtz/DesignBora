import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Rangi kuu - teal/navy giza (kutoka header, hero section)
  static const Color primary = Color(0xFF0D3B3E);
  static const Color primaryLight = Color(0xFF14555A);

  // Rangi ya pili - orange (CTA buttons)
  static const Color accent = Color(0xFFE8823C);
  static const Color accentDark = Color(0xFFD16F2C);

  // Neutrals
  static const Color background = Color(0xFFF5F6F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  // Status colors (kwa Order status badges)
  static const Color statusPaid = Color(0xFF3B82F6);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusDraftSubmitted = Color(0xFF8B5CF6);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusDisputed = Color(0xFFEF4444);

  // Rating stars
  static const Color star = Color(0xFFFBBF24);
}
