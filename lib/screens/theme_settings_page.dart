import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_theme_tokens.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final customPalette = AppThemePalette.custom(
      primaryValue: provider.customThemePrimaryValue,
      accentValue: provider.customThemeAccentValue,
    );

    return Scaffold(
      appBar: AppBar(title: Text(provider.t('theme_color'))),
      body: SafeArea(
        child: LongScreenshotScrollCapture(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            padding: AppSpacing.pagePadding,
            children: [
              const AppSectionTitle(title: '显示模式', subtitle: '选择跟随系统、浅色或深色外观'),
              AppSurface(
                child: AppActionTile(
                  icon: Icons.brightness_6_outlined,
                  title: '显示模式',
                  subtitle: _appThemeModeLabel(provider.appThemeMode),
                  onTap: () => _selectAppThemeMode(context, provider),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionTitle(
                title: provider.t('theme_color'),
                subtitle: provider.t('theme_color_subtitle'),
              ),
              AppSurface(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      for (
                        int index = 0;
                        index < AppThemePalette.values.length;
                        index++
                      ) ...[
                        _ThemePaletteTile(
                          palette: AppThemePalette.values[index],
                          selected:
                              provider.themePaletteId ==
                              AppThemePalette.values[index].id,
                          label: provider.t(
                            AppThemePalette.values[index].nameKey,
                          ),
                          onTap: () => provider.changeThemePalette(
                            AppThemePalette.values[index].id,
                          ),
                        ),
                        if (index != AppThemePalette.values.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionTitle(
                title: provider.t('theme_custom'),
                subtitle: provider.t('theme_custom_subtitle'),
              ),
              AppSurface(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ThemePaletteTile(
                        palette: customPalette,
                        selected:
                            provider.themePaletteId == AppThemePalette.customId,
                        label: provider.t('theme_custom'),
                        onTap: () => provider.changeCustomThemeColors(
                          primaryValue: provider.customThemePrimaryValue,
                          accentValue: provider.customThemeAccentValue,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ColorPickerTitle(provider.t('primary_color')),
                      const SizedBox(height: AppSpacing.md),
                      _ThemeColorGrid(
                        keyPrefix: 'theme-primary-color',
                        selectedValue: provider.customThemePrimaryValue,
                        onSelected: (value) => provider.changeCustomThemeColors(
                          primaryValue: value,
                          accentValue: provider.customThemeAccentValue,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ColorPickerTitle(provider.t('accent_color')),
                      const SizedBox(height: AppSpacing.md),
                      _ThemeColorGrid(
                        keyPrefix: 'theme-accent-color',
                        selectedValue: provider.customThemeAccentValue,
                        onSelected: (value) => provider.changeCustomThemeColors(
                          primaryValue: provider.customThemePrimaryValue,
                          accentValue: value,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectAppThemeMode(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selected = await showAppOptionPicker<AppThemeMode>(
      context,
      title: '显示模式',
      selectedValue: provider.appThemeMode,
      options: const [
        AppPickerOption(value: AppThemeMode.system, label: '跟随系统'),
        AppPickerOption(value: AppThemeMode.light, label: '浅色'),
        AppPickerOption(value: AppThemeMode.dark, label: '深色'),
      ],
    );
    if (!context.mounted || selected == null) {
      return;
    }
    await provider.changeAppThemeMode(selected);
  }
}

String _appThemeModeLabel(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => '跟随系统',
    AppThemeMode.light => '浅色',
    AppThemeMode.dark => '深色',
  };
}

class _ThemePaletteTile extends StatelessWidget {
  const _ThemePaletteTile({
    required this.palette,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AppThemePalette palette;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final borderRadius = BorderRadius.circular(AppRadii.lg);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: AppColors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.primarySoft : AppColors.transparent,
              borderRadius: borderRadius,
              border: Border.all(
                color: selected ? palette.primary : AppColors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                _PalettePreview(palette: palette),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected
                          ? palette.accent
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: palette.accent)
                else
                  Icon(Icons.chevron_right, color: tokens.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 38,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 5,
            child: _ColorSwatch(color: palette.primary),
          ),
          Positioned(
            left: 24,
            top: 5,
            child: _ColorSwatch(color: palette.accent),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    return Container(
      width: 34,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tokens.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerTitle extends StatelessWidget {
  const _ColorPickerTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ThemeColorGrid extends StatelessWidget {
  const _ThemeColorGrid({
    required this.keyPrefix,
    required this.selectedValue,
    required this.onSelected,
  });

  final String keyPrefix;
  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final entry in AppColors.themePickerPaletteValues.indexed)
          _ThemeColorChip(
            keyPrefix: keyPrefix,
            index: entry.$1,
            colorValue: entry.$2,
            selected: entry.$2 == selectedValue,
            onTap: () => onSelected(entry.$2),
          ),
      ],
    );
  }
}

class _ThemeColorChip extends StatelessWidget {
  const _ThemeColorChip({
    required this.keyPrefix,
    required this.index,
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final String keyPrefix;
  final int index;
  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final tokens = appThemeTokensOf(context);
    return Semantics(
      key: ValueKey('$keyPrefix-$index'),
      button: true,
      selected: selected,
      label: '颜色 ${index + 1}，${AppColors.colorName(colorValue)}',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : tokens.surface,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.30 : 0.16),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  color: bestContrastingForeground(color),
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
