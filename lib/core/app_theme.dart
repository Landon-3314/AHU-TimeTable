import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_constants.dart';
import 'app_page_transitions.dart';
import 'app_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light({
    AppThemePalette palette = AppThemePalette.defaultPalette,
  }) {
    return _build(brightness: Brightness.light, palette: palette);
  }

  static ThemeData dark({
    AppThemePalette palette = AppThemePalette.defaultPalette,
  }) {
    return _build(brightness: Brightness.dark, palette: palette);
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppThemePalette palette,
  }) {
    final tokens = brightness == Brightness.dark
        ? AppThemeTokens.dark.copyWith(
            pageBackground: _tint(
              AppThemeTokens.dark.pageBackground,
              palette.primary,
              0.10,
            ),
            surface: _tint(AppThemeTokens.dark.surface, palette.primary, 0.08),
            surfaceRaised: _tint(
              AppThemeTokens.dark.surfaceRaised,
              palette.primary,
              0.10,
            ),
            surfaceMuted: _tint(
              AppThemeTokens.dark.surfaceMuted,
              palette.primary,
              0.12,
            ),
            divider: _tint(AppThemeTokens.dark.divider, palette.primary, 0.18),
            infoSurface: _tint(
              AppThemeTokens.dark.infoSurface,
              palette.primary,
              0.18,
            ),
          )
        : AppThemeTokens.light.copyWith(
            pageBackground: palette.scaffoldBackground,
            surface: _tint(Colors.white, palette.primary, 0.02),
            surfaceRaised: _tint(Colors.white, palette.primary, 0.05),
            surfaceMuted: palette.surfaceMuted,
            divider: palette.divider,
            infoSurface: palette.primarySoft,
          );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          primaryContainer: brightness == Brightness.light
              ? palette.primarySoft
              : tokens.surfaceMuted,
          secondary: palette.accent,
          secondaryContainer: brightness == Brightness.light
              ? palette.accentSoft
              : tokens.surfaceRaised,
          surface: tokens.surface,
          onPrimary: bestContrastingForeground(palette.primary),
          onSecondary: bestContrastingForeground(palette.accent),
          onSurface: tokens.textPrimary,
          error: AppColors.danger,
          onError: bestContrastingForeground(AppColors.danger),
        );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.pageBackground,
      extensions: <ThemeExtension<dynamic>>[tokens],
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.pageBackground,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.secondary),
        actionsIconTheme: IconThemeData(color: colorScheme.secondary),
      ),
      iconTheme: IconThemeData(color: colorScheme.secondary),
      listTileTheme: ListTileThemeData(iconColor: colorScheme.secondary),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: tokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.textPrimary,
        contentTextStyle: TextStyle(
          color: bestContrastingForeground(tokens.textPrimary),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        surfaceTintColor: AppColors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: tokens.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: tokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: tokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.42)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: tokens.surfaceMuted,
        labelStyle: TextStyle(color: tokens.textPrimary),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: tokens.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.surface),
          ),
        ),
      ),
      dividerColor: tokens.divider,
    );
  }

  static Color _tint(Color base, Color tint, double amount) {
    return Color.lerp(base, tint, amount)!;
  }
}
