import 'dart:math' as math;

import 'package:flutter/material.dart';

class GuidedTourStep {
  const GuidedTourStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

Future<void> showGuidedTourOverlay({
  required BuildContext context,
  required List<GuidedTourStep> steps,
  required String nextLabel,
  required String doneLabel,
  required String Function(int currentStep, int totalSteps) stepLabelBuilder,
}) {
  if (steps.isEmpty) {
    return Future<void>.value();
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '功能引导',
    barrierColor: Colors.transparent,
    pageBuilder: (context, _, _) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: '功能引导',
        child: GuidedTourOverlay(
          steps: steps,
          nextLabel: nextLabel,
          doneLabel: doneLabel,
          stepLabelBuilder: stepLabelBuilder,
          onCompleted: () => Navigator.of(context).pop(),
        ),
      );
    },
  );
}

class GuidedTourOverlay extends StatefulWidget {
  const GuidedTourOverlay({
    super.key,
    required this.steps,
    required this.nextLabel,
    required this.doneLabel,
    required this.stepLabelBuilder,
    required this.onCompleted,
  });

  final List<GuidedTourStep> steps;
  final String nextLabel;
  final String doneLabel;
  final String Function(int currentStep, int totalSteps) stepLabelBuilder;
  final VoidCallback onCompleted;

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  static const double _screenPadding = 16;
  static const double _targetPadding = 8;
  static const double _cardGap = 12;
  static const double _cardMaxWidth = 360;
  static const double _cardMinHeight = 168;

  int _stepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final step = widget.steps[_stepIndex];
    final targetRect = _targetRectFor(step.targetKey, size);
    final cardWidth = math.min(
      size.width - (_screenPadding * 2),
      _cardMaxWidth,
    );
    final estimatedCardHeight = math.min(
      size.height - (_screenPadding * 2),
      math.max(_cardMinHeight, size.height * 0.24),
    );
    final cardLeft = _clampDouble(
      targetRect.center.dx - (cardWidth / 2),
      _screenPadding,
      size.width - cardWidth - _screenPadding,
    );
    final cardTop = _cardTopFor(
      targetRect: targetRect,
      screenHeight: size.height,
      cardHeight: estimatedCardHeight,
      topPadding: mediaQuery.padding.top,
      bottomPadding: mediaQuery.padding.bottom,
    );

    return PopScope(
      canPop: false,
      child: BlockSemantics(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GuidedTourScrimPainter(targetRect: targetRect),
                ),
              ),
              Positioned.fromRect(
                rect: targetRect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cardLeft,
                top: cardTop,
                width: cardWidth,
                child: _GuidedTourCard(
                  title: step.title,
                  body: step.body,
                  stepLabel: widget.stepLabelBuilder(
                    _stepIndex + 1,
                    widget.steps.length,
                  ),
                  actionLabel: _isLastStep
                      ? widget.doneLabel
                      : widget.nextLabel,
                  onPressed: _advance,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isLastStep => _stepIndex == widget.steps.length - 1;

  void _advance() {
    if (_isLastStep) {
      widget.onCompleted();
      return;
    }

    setState(() {
      _stepIndex += 1;
    });
  }

  Rect _targetRectFor(GlobalKey key, Size screenSize) {
    final context = key.currentContext;
    if (context == null) {
      return _fallbackRect(screenSize);
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return _fallbackRect(screenSize);
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    return rect.inflate(_targetPadding).intersect(Offset.zero & screenSize);
  }

  Rect _fallbackRect(Size screenSize) {
    const fallbackSize = Size(96, 56);
    final left = (screenSize.width - fallbackSize.width) / 2;
    final top = math.max(_screenPadding, screenSize.height * 0.18);
    return Offset(left, top) & fallbackSize;
  }

  double _cardTopFor({
    required Rect targetRect,
    required double screenHeight,
    required double cardHeight,
    required double topPadding,
    required double bottomPadding,
  }) {
    final topLimit = topPadding + _screenPadding;
    final bottomLimit = screenHeight - bottomPadding - _screenPadding;
    final below = targetRect.bottom + _cardGap;
    if (below + cardHeight <= bottomLimit) {
      return below;
    }

    final above = targetRect.top - _cardGap - cardHeight;
    if (above >= topLimit) {
      return above;
    }

    return _clampDouble(
      below,
      topLimit,
      math.max(topLimit, bottomLimit - cardHeight),
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (max < min) {
      return min;
    }
    return value.clamp(min, max).toDouble();
  }
}

class _GuidedTourCard extends StatelessWidget {
  const _GuidedTourCard({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String stepLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: '$stepLabel，$title，$body',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stepLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(widthFactor: 1, child: Text(actionLabel)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedTourScrimPainter extends CustomPainter {
  const _GuidedTourScrimPainter({required this.targetRect});

  final Rect targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, const Radius.circular(14)),
      );
    canvas.drawPath(
      scrimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.66),
    );
  }

  @override
  bool shouldRepaint(_GuidedTourScrimPainter oldDelegate) {
    return targetRect != oldDelegate.targetRect;
  }
}
