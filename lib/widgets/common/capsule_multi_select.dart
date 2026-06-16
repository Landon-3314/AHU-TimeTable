import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';

class CapsuleMultiSelectOption<T> {
  const CapsuleMultiSelectOption({
    required this.value,
    required this.label,
    this.semanticLabel,
  });

  final T value;
  final String label;
  final String? semanticLabel;
}

class CapsuleMultiSelect<T> extends StatefulWidget {
  const CapsuleMultiSelect({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.enableDragSelect = false,
    this.singleLine = false,
    this.themeColor,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.chipPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    this.onDragSelectionActiveChanged,
  });

  final List<CapsuleMultiSelectOption<T>> options;
  final Set<T> selectedValues;
  final ValueChanged<Set<T>> onChanged;
  final bool enableDragSelect;
  final bool singleLine;
  final Color? themeColor;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry chipPadding;
  final ValueChanged<bool>? onDragSelectionActiveChanged;

  @override
  State<CapsuleMultiSelect<T>> createState() => _CapsuleMultiSelectState<T>();
}

class _CapsuleMultiSelectState<T> extends State<CapsuleMultiSelect<T>> {
  final Map<T, GlobalKey> _chipKeys = <T, GlobalKey>{};
  final Set<T> _dragTouchedValues = <T>{};
  Set<T>? _dragWorkingSelection;
  bool? _dragShouldSelect;
  Offset? _pendingDragStartPosition;

  Set<T> get _effectiveSelection =>
      _dragWorkingSelection ?? widget.selectedValues;

  @override
  void initState() {
    super.initState();
    _syncChipKeys();
  }

  @override
  void didUpdateWidget(CapsuleMultiSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncChipKeys();
  }

  void _syncChipKeys() {
    final values = widget.options.map((option) => option.value).toSet();
    _chipKeys.removeWhere((value, _) => !values.contains(value));
    for (final value in values) {
      _chipKeys.putIfAbsent(value, GlobalKey.new);
    }
  }

  void _toggleValue(T value) {
    final nextSelection = {...widget.selectedValues};
    if (nextSelection.contains(value)) {
      nextSelection.remove(value);
    } else {
      nextSelection.add(value);
    }
    widget.onChanged(nextSelection);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pendingDragStartPosition = event.position;
    widget.onDragSelectionActiveChanged?.call(true);
  }

  void _handlePanStart(DragStartDetails details) {
    final startPosition = _pendingDragStartPosition ?? details.globalPosition;
    _startDragAt(startPosition);
    if (details.globalPosition != startPosition) {
      _applyDragAt(details.globalPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragWorkingSelection == null) {
      _startDragAt(details.globalPosition);
      return;
    }
    _applyDragAt(details.globalPosition);
  }

  void _startDragAt(Offset globalPosition) {
    final value = _valueAt(globalPosition);
    if (value == null) {
      return;
    }

    _dragTouchedValues.clear();
    _dragShouldSelect = !widget.selectedValues.contains(value);
    _dragWorkingSelection = {...widget.selectedValues};
    _applyDraggedValue(value);
  }

  void _applyDragAt(Offset globalPosition) {
    final value = _valueAt(globalPosition);
    if (value == null) {
      return;
    }
    _applyDraggedValue(value);
  }

  void _applyDraggedValue(T value) {
    if (_dragTouchedValues.contains(value)) {
      return;
    }

    final shouldSelect = _dragShouldSelect;
    if (shouldSelect == null) {
      return;
    }

    final nextSelection = {...(_dragWorkingSelection ?? widget.selectedValues)};
    if (shouldSelect) {
      nextSelection.add(value);
    } else {
      nextSelection.remove(value);
    }

    setState(() {
      _dragTouchedValues.add(value);
      _dragWorkingSelection = nextSelection;
    });
    widget.onChanged({...nextSelection});
  }

  void _endDrag() {
    widget.onDragSelectionActiveChanged?.call(false);
    if (_dragWorkingSelection == null &&
        _dragTouchedValues.isEmpty &&
        _dragShouldSelect == null) {
      return;
    }
    setState(() {
      _dragWorkingSelection = null;
      _dragTouchedValues.clear();
      _dragShouldSelect = null;
      _pendingDragStartPosition = null;
    });
  }

  T? _valueAt(Offset globalPosition) {
    for (final option in widget.options) {
      final context = _chipKeys[option.value]?.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.contains(globalPosition)) {
        return option.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in widget.options)
        KeyedSubtree(
          key: ValueKey<String>('capsule_multi_select_${option.value}'),
          child: _CapsuleChip(
            key: _chipKeys[option.value],
            label: option.label,
            semanticLabel: option.semanticLabel,
            selected: _effectiveSelection.contains(option.value),
            themeColor: widget.themeColor,
            padding: widget.chipPadding,
            onTap: () => _toggleValue(option.value),
          ),
        ),
    ];
    final content = widget.singleLine
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _spacedRowChildren(chips)),
          )
        : Wrap(
            spacing: widget.spacing,
            runSpacing: widget.runSpacing,
            children: chips,
          );

    if (!widget.enableDragSelect) {
      return content;
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: (_) => _endDrag(),
      onPointerCancel: (_) => _endDrag(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: (_) => _endDrag(),
        onPanCancel: _endDrag,
        child: content,
      ),
    );
  }

  List<Widget> _spacedRowChildren(List<Widget> children) {
    if (children.length < 2) {
      return children;
    }

    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        result.add(SizedBox(width: widget.spacing));
      }
      result.add(children[index]);
    }
    return result;
  }
}

class _CapsuleChip extends StatelessWidget {
  const _CapsuleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.padding,
    required this.onTap,
    this.semanticLabel,
    this.themeColor,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final Color? themeColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appThemeTokensOf(context);
    final selectedColor = themeColor ?? colorScheme.primary;
    final backgroundColor = selected
        ? colorScheme.primaryContainer
        : tokens.surfaceRaised;
    final borderColor = selected ? selectedColor : tokens.divider;
    final textColor = selected
        ? themeColor ?? colorScheme.secondary
        : colorScheme.onSurface;
    final borderRadius = BorderRadius.circular(AppRadii.pill);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withValues(
                    alpha: selected ? 0.08 : 0.04,
                  ),
                  blurRadius: selected ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
