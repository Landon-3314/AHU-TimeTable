import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pageBackground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.infoSurface,
    required this.warningSurface,
    required this.dangerSurface,
  });

  final Color pageBackground;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color infoSurface;
  final Color warningSurface;
  final Color dangerSurface;

  static const AppThemeTokens light = AppThemeTokens(
    pageBackground: Color(0xFFF3F7FF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF8FAFC),
    surfaceMuted: Color(0xFFF1F5F9),
    divider: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF334155),
    textTertiary: Color(0xFF64748B),
    infoSurface: Color(0xFFEFF6FF),
    warningSurface: Color(0xFFFFFBEB),
    dangerSurface: Color(0xFFFEE2E2),
  );

  static const AppThemeTokens dark = AppThemeTokens(
    pageBackground: Color(0xFF0F172A),
    surface: Color(0xFF172033),
    surfaceRaised: Color(0xFF1E293B),
    surfaceMuted: Color(0xFF263449),
    divider: Color(0xFF3A4A62),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF94A3B8),
    infoSurface: Color(0xFF172554),
    warningSurface: Color(0xFF422006),
    dangerSurface: Color(0xFF450A0A),
  );

  @override
  AppThemeTokens copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? infoSurface,
    Color? warningSurface,
    Color? dangerSurface,
  }) {
    return AppThemeTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      infoSurface: infoSurface ?? this.infoSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return AppThemeTokens(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
    );
  }
}

AppThemeTokens appThemeTokensOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppThemeTokens>() ??
      (theme.brightness == Brightness.dark
          ? AppThemeTokens.dark
          : AppThemeTokens.light);
}

double contrastRatio(Color left, Color right) {
  final leftLuminance = left.computeLuminance();
  final rightLuminance = right.computeLuminance();
  final lighter = math.max(leftLuminance, rightLuminance);
  final darker = math.min(leftLuminance, rightLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

Color bestContrastingForeground(Color background) {
  return contrastRatio(background, Colors.black) >=
          contrastRatio(background, Colors.white)
      ? Colors.black
      : Colors.white;
}
