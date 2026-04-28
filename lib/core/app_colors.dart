import 'package:flutter/material.dart';

class AppThemePalette {
  const AppThemePalette({
    required this.id,
    required this.nameKey,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.scaffoldBackground,
    required this.surfaceMuted,
    required this.divider,
    required this.textPrimary,
  });

  final String id;
  final String nameKey;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color scaffoldBackground;
  final Color surfaceMuted;
  final Color divider;
  final Color textPrimary;

  static const AppThemePalette defaultPalette = AppThemePalette(
    id: 'teal_orange',
    nameKey: 'theme_teal_orange',
    primary: Color(0xFF0D9488),
    primaryDark: Color(0xFF115E59),
    primarySoft: Color(0xFFCCFBF1),
    accent: Color(0xFFF97316),
    accentSoft: Color(0xFFFFEDD5),
    scaffoldBackground: Color(0xFFF0FDFA),
    surfaceMuted: Color(0xFFEFFDF8),
    divider: Color(0xFFD6EEE8),
    textPrimary: Color(0xFF134E4A),
  );

  static const List<AppThemePalette> values = <AppThemePalette>[
    defaultPalette,
    AppThemePalette(
      id: 'blue_amber',
      nameKey: 'theme_blue_amber',
      primary: Color(0xFF2563EB),
      primaryDark: Color(0xFF1E3A8A),
      primarySoft: Color(0xFFDBEAFE),
      accent: Color(0xFFF59E0B),
      accentSoft: Color(0xFFFEF3C7),
      scaffoldBackground: Color(0xFFF3F7FF),
      surfaceMuted: Color(0xFFEFF6FF),
      divider: Color(0xFFD6E4FF),
      textPrimary: Color(0xFF172554),
    ),
    AppThemePalette(
      id: 'violet_pink',
      nameKey: 'theme_violet_pink',
      primary: Color(0xFF7C3AED),
      primaryDark: Color(0xFF4C1D95),
      primarySoft: Color(0xFFEDE9FE),
      accent: Color(0xFFDB2777),
      accentSoft: Color(0xFFFCE7F3),
      scaffoldBackground: Color(0xFFFAF7FF),
      surfaceMuted: Color(0xFFF5F3FF),
      divider: Color(0xFFE4D7FF),
      textPrimary: Color(0xFF2E1065),
    ),
    AppThemePalette(
      id: 'green_lime',
      nameKey: 'theme_green_lime',
      primary: Color(0xFF16A34A),
      primaryDark: Color(0xFF14532D),
      primarySoft: Color(0xFFDCFCE7),
      accent: Color(0xFF84CC16),
      accentSoft: Color(0xFFECFCCB),
      scaffoldBackground: Color(0xFFF3FCF5),
      surfaceMuted: Color(0xFFF0FDF4),
      divider: Color(0xFFD4EED8),
      textPrimary: Color(0xFF14532D),
    ),
  ];

  static AppThemePalette byId(String id) {
    for (final palette in values) {
      if (palette.id == id) {
        return palette;
      }
    }
    return defaultPalette;
  }
}

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primarySoft = Color(0xFFCCFBF1);
  static const Color accent = Color(0xFFF97316);
  static const Color accentSoft = Color(0xFFFFEDD5);
  static const Color scaffoldBackground = Color(0xFFF0FDFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFF8FFFD);
  static const Color surfaceMuted = Color(0xFFEFFDF8);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color warningAccent = Color(0xFFF59E0B);
  static const Color warningBorder = Color(0xFFFCD34D);
  static const Color infoBorder = Color(0xFF99F6E4);
  static const Color divider = Color(0xFFD6EEE8);
  static const Color textPrimary = Color(0xFF134E4A);
  static const Color textSecondary = Color(0xFF4B635F);
  static const Color textTertiary = Color(0xFF6B7C78);
  static const Color success = Color(0xFF0F9F6E);
  static const Color danger = Color(0xFFD64545);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color transparent = Colors.transparent;

  static const List<int> coursePaletteValues = <int>[
    0xFF0D9488,
    0xFF2563EB,
    0xFFF97316,
    0xFFDB2777,
    0xFF7C3AED,
    0xFF16A34A,
  ];
}
