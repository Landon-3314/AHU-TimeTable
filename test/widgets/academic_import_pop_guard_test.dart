import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/screens/import_course_page.dart';

void main() {
  testWidgets('academic import pop guard blocks route pop while busy', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AcademicImportPopGuard(
                      canLeave: false,
                      child: Scaffold(body: Text('importing')),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('importing'), findsOneWidget);

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('importing'), findsOneWidget);
  });
}
