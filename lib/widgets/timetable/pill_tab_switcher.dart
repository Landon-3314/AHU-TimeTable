import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';

class PillTabSwitcher<T> extends StatelessWidget {
  const PillTabSwitcher({
    super.key,
    required this.indicatorKey,
    required this.selectedValue,
    required this.itemWidth,
    required this.items,
    required this.onSelected,
  });

  final Key indicatorKey;
  final T selectedValue;
  final double itemWidth;
  final List<PillTabItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final selectedIndex = items.indexWhere(
      (item) => item.value == selectedValue,
    );
    assert(selectedIndex >= 0);
    final indicatorAlignment = items.length == 1
        ? Alignment.center
        : Alignment(-1 + (2 * selectedIndex / (items.length - 1)), 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tokens.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: SizedBox(
          width: itemWidth * items.length,
          height: 36,
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppDurations.fast,
                curve: Curves.easeOutCubic,
                alignment: indicatorAlignment,
                child: DecoratedBox(
                  key: indicatorKey,
                  decoration: BoxDecoration(
                    color: tokens.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(width: itemWidth, height: 36),
                ),
              ),
              Row(
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      height: 36,
                      child: _PillTab(
                        item: item,
                        selected: item.value == selectedValue,
                        onTap: () => onSelected(item.value),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PillTabItem<T> {
  const PillTabItem({this.key, required this.value, required this.label});

  final Key? key;
  final T value;
  final Widget label;
}

class _PillTab<T> extends StatelessWidget {
  const _PillTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillTabItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appThemeTokensOf(context);
    final label = item.label;
    return Semantics(
      key: item.key,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: selected ? colorScheme.secondary : tokens.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}
