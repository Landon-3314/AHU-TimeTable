import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../providers/settings_provider.dart';
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
                          ? palette.primaryDark
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: palette.primary)
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
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
    return Container(
      width: 34,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.surface, width: 2),
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
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final colorValue in AppColors.themePickerPaletteValues)
          _ThemeColorChip(
            colorValue: colorValue,
            selected: colorValue == selectedValue,
            onTap: () => onSelected(colorValue),
          ),
      ],
    );
  }
}

class _ThemeColorChip extends StatelessWidget {
  const _ThemeColorChip({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Semantics(
      button: true,
      selected: selected,
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
                  : AppColors.surface,
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
              ? const Icon(Icons.check, color: AppColors.onPrimary, size: 20)
              : null,
        ),
      ),
    );
  }
}
