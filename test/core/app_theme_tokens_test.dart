import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/core/app_colors.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/core/app_theme_tokens.dart';

void main() {
  test('best contrasting foreground chooses black or white', () {
    expect(bestContrastingForeground(const Color(0xFFFFFFFF)), Colors.black);
    expect(bestContrastingForeground(const Color(0xFF111827)), Colors.white);
  });

  test('preset palette foreground reaches wcag aa contrast', () {
    for (final colorValue in {
      ...AppColors.coursePaletteValues,
      ...AppColors.themePickerPaletteValues,
    }) {
      final background = Color(colorValue);
      final foreground = bestContrastingForeground(background);

      expect(
        contrastRatio(background, foreground),
        greaterThanOrEqualTo(4.5),
        reason: '0x${colorValue.toRadixString(16)}',
      );
    }
  });

  test('dark theme publishes primary-tinted semantic tokens', () {
    final theme = AppTheme.dark();
    final tokens = theme.extension<AppThemeTokens>();

    expect(theme.brightness, Brightness.dark);
    expect(tokens, isNotNull);
    expect(
      tokens!.pageBackground,
      Color.lerp(
        AppThemeTokens.dark.pageBackground,
        AppThemePalette.defaultPalette.primary,
        0.10,
      ),
    );
    expect(theme.scaffoldBackgroundColor, tokens.pageBackground);
    expect(theme.colorScheme.surface, tokens.surface);
  });
}
