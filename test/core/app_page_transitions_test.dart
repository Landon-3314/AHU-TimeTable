import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/core/app_page_transitions.dart';
import 'package:AnKe/core/app_theme.dart';

void main() {
  testWidgets(
    'uses slide and fade without scaling when animations are enabled',
    (tester) async {
      final route = PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const SizedBox.shrink(),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                return const AppPageTransitionsBuilder().buildTransitions<void>(
                  route,
                  context,
                  const AlwaysStoppedAnimation<double>(0.5),
                  const AlwaysStoppedAnimation<double>(0),
                  const SizedBox(key: ValueKey('page')),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
    },
  );

  testWidgets('returns the child unchanged when animations are disabled', (
    tester,
  ) async {
    final route = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    const child = SizedBox(key: ValueKey('page'));
    late Widget transition;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              transition = const AppPageTransitionsBuilder()
                  .buildTransitions<void>(
                    route,
                    context,
                    const AlwaysStoppedAnimation<double>(0.5),
                    const AlwaysStoppedAnimation<double>(0),
                    child,
                  );
              return transition;
            },
          ),
        ),
      ),
    );

    expect(identical(transition, child), isTrue);
    expect(find.byKey(const ValueKey('page')), findsOneWidget);
  });

  test(
    'light theme uses the app page transition on every supported platform',
    () {
      final builders = AppTheme.light().pageTransitionsTheme.builders;

      expect(
        builders[TargetPlatform.android],
        isA<AppPageTransitionsBuilder>(),
      );
      expect(builders[TargetPlatform.iOS], isA<AppPageTransitionsBuilder>());
      expect(builders[TargetPlatform.macOS], isA<AppPageTransitionsBuilder>());
      expect(
        builders[TargetPlatform.windows],
        isA<AppPageTransitionsBuilder>(),
      );
      expect(builders[TargetPlatform.linux], isA<AppPageTransitionsBuilder>());
    },
  );
}
