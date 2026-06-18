import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';

enum TimetableToolbarAction { overview, addCourse }

class TimetableToolbarMenuRoute extends PopupRoute<TimetableToolbarAction> {
  TimetableToolbarMenuRoute({
    required this.anchorRect,
    required String barrierLabel,
    required this.addCourseLabel,
    this.overviewGuideKey,
    this.addCourseGuideKey,
    this.onMenuReady,
  }) : _barrierLabel = barrierLabel;

  final Rect anchorRect;
  final String _barrierLabel;
  final String addCourseLabel;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;
  final VoidCallback? onMenuReady;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => AppDurations.switcher;

  @override
  Duration get reverseTransitionDuration => AppDurations.switcher;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _TimetableToolbarMenuLayout(anchorRect: anchorRect),
      child: _TimetableToolbarMenu(
        animation: animation,
        addCourseLabel: addCourseLabel,
        overviewGuideKey: overviewGuideKey,
        addCourseGuideKey: addCourseGuideKey,
        onMenuReady: onMenuReady,
      ),
    );
  }
}

class _TimetableToolbarMenuLayout extends SingleChildLayoutDelegate {
  const _TimetableToolbarMenuLayout({required this.anchorRect});

  static const double _screenPadding = AppSpacing.sm;
  static const double _anchorGap = AppSpacing.xs;

  final Rect anchorRect;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        math.max(0, constraints.maxWidth - _screenPadding * 2),
        math.max(0, constraints.maxHeight - _screenPadding * 2),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(_screenPadding, size.width - childSize.width);
    final left = (anchorRect.right - childSize.width)
        .clamp(_screenPadding, maxLeft)
        .toDouble();
    final maxTop = math.max(_screenPadding, size.height - childSize.height);
    final belowAnchor = anchorRect.bottom + _anchorGap;
    final aboveAnchor = anchorRect.top - _anchorGap - childSize.height;
    final preferredTop = belowAnchor + childSize.height <= size.height
        ? belowAnchor
        : aboveAnchor;
    final top = preferredTop.clamp(_screenPadding, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _TimetableToolbarMenuLayout oldDelegate) {
    return anchorRect != oldDelegate.anchorRect;
  }
}

class _TimetableToolbarMenu extends StatefulWidget {
  const _TimetableToolbarMenu({
    required this.animation,
    required this.addCourseLabel,
    this.overviewGuideKey,
    this.addCourseGuideKey,
    this.onMenuReady,
  });

  static const _contentFadeInCurve = Interval(
    40 / 220,
    160 / 220,
    curve: Curves.easeOutCubic,
  );
  static const _contentFadeOutCurve = Interval(
    60 / 220,
    1,
    curve: Curves.easeInCubic,
  );

  final Animation<double> animation;
  final String addCourseLabel;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;
  final VoidCallback? onMenuReady;

  @override
  State<_TimetableToolbarMenu> createState() => _TimetableToolbarMenuState();
}

class _TimetableToolbarMenuState extends State<_TimetableToolbarMenu> {
  bool _guideTriggered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.animation,
      child: _TimetableToolbarMenuItems(
        onSelected: (action) => Navigator.of(context).pop(action),
        addCourseLabel: widget.addCourseLabel,
        overviewGuideKey: widget.overviewGuideKey,
        addCourseGuideKey: widget.addCourseGuideKey,
      ),
      builder: (context, child) {
        final isClosing = widget.animation.status == AnimationStatus.reverse;
        final revealProgress =
            (isClosing ? Curves.easeInCubic : Curves.easeOutCubic).transform(
              widget.animation.value,
            );
        final contentProgress =
            (isClosing
                    ? _TimetableToolbarMenu._contentFadeOutCurve
                    : _TimetableToolbarMenu._contentFadeInCurve)
                .transform(widget.animation.value);

        // 菜单展开完成后触发引导回调（仅触发一次）
        if (!_guideTriggered &&
            widget.onMenuReady != null &&
            widget.animation.status == AnimationStatus.completed) {
          _guideTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onMenuReady?.call();
          });
        }
        return Opacity(
          key: const ValueKey('narrow-toolbar-menu-container-opacity'),
          opacity: revealProgress,
          child: DecoratedBox(
            key: const ValueKey('narrow-toolbar-menu-shadow'),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              border: Border.all(color: tokens.divider),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.topRight,
                widthFactor: 0.14 + 0.86 * revealProgress,
                heightFactor: 0.11 + 0.89 * revealProgress,
                child: IntrinsicWidth(
                  child: Material(
                    key: const ValueKey('narrow-toolbar-menu-card'),
                    color: tokens.surfaceRaised,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Opacity(
                        key: const ValueKey(
                          'narrow-toolbar-menu-content-opacity',
                        ),
                        opacity: contentProgress,
                        child: Transform.translate(
                          offset: Offset(0, -4 * (1 - contentProgress)),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimetableToolbarMenuItems extends StatelessWidget {
  const _TimetableToolbarMenuItems({
    required this.onSelected,
    required this.addCourseLabel,
    this.overviewGuideKey,
    this.addCourseGuideKey,
  });

  final ValueChanged<TimetableToolbarAction> onSelected;
  final String addCourseLabel;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key:
              overviewGuideKey ??
              const ValueKey('narrow-toolbar-menu-action-overview'),
          child: _TimetableToolbarMenuItem(
            icon: Icons.dashboard_outlined,
            label: '总览',
            onTap: () => onSelected(TimetableToolbarAction.overview),
          ),
        ),
        KeyedSubtree(
          key:
              addCourseGuideKey ??
              const ValueKey('narrow-toolbar-menu-action-add-course'),
          child: _TimetableToolbarMenuItem(
            icon: Icons.add,
            label: addCourseLabel,
            onTap: () => onSelected(TimetableToolbarAction.addCourse),
          ),
        ),
      ],
    );
  }
}

class _TimetableToolbarMenuItem extends StatelessWidget {
  const _TimetableToolbarMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, color: colorScheme.secondary, size: 18),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
