import 'package:flutter/material.dart';

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static final Animatable<Offset> _positionTween = Tween<Offset>(
    begin: const Offset(0.06, 0),
    end: Offset.zero,
  );

  static final Animatable<double> _opacityTween = Tween<double>(
    begin: 0,
    end: 1,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: _opacityTween.animate(curvedAnimation),
      child: SlideTransition(
        position: _positionTween.animate(curvedAnimation),
        textDirection: Directionality.maybeOf(context),
        child: child,
      ),
    );
  }
}
