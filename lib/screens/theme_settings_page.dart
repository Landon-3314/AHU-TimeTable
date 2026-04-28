import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/app_ui.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(provider.t('theme_color'))),
      body: SafeArea(
        child: ListView(
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
          ],
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.primarySoft : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.lg),
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
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
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
