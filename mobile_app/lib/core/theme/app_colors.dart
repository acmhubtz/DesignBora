import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Teal/Navy - rangi kuu ya brand (kutoka logo, hero, sidebar ya admin)
  static const Color primary = Color(0xFF0B3B3E);
  static const Color primaryDark = Color(0xFF072829);
  static const Color primaryLight = Color(0xFF155358);

  static const List<Color> primaryGradient = [
    Color(0xFF0B3B3E),
    Color(0xFF166468),
  ];

  // Auth background - nyeusi kabisa (kutoka login/register screenshots)
  static const Color authBackground = Color(0xFF141414);
  static const Color authCard = Color(0xFFFFFFFF);

  // Orange - CTA buttons, highlights
  static const Color accent = Color(0xFFF07F2B);
  static const Color accentDark = Color(0xFFD96A1A);
  static const Color accentLight = Color(0xFFFFA866);

  // Neutrals
  static const Color background = Color(0xFFF7F8F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF16181A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE8EAED);
  static const Color borderDark = Color(0xFFD1D5DB);

  // Status colors (Order badges)
  static const Color statusPaid = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusDraftSubmitted = Color(0xFF8B5CF6);
  static const Color statusCompleted = Color(0xFF059669);
  static const Color statusDisputed = Color(0xFFDC2626);
  static const Color statusPending = Color(0xFFF97316);

  // Rating
  static const Color star = Color(0xFFFBBF24);

  // Shadows (zinatumika kama BoxShadow color)
  static Color shadowSoft = Colors.black.withValues(alpha: 0.06);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.12);
  static Color shadowStrong = Colors.black.withValues(alpha: 0.25);
}
