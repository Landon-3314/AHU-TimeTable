import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/widgets/semester_initialization_guard.dart';

void main() {
  testWidgets('semester initialization guard no longer blocks actions', (
    tester,
  ) async {
    var allowed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () async {
                allowed = await ensureCurrentSemesterInitialized(context);
              },
              child: const Text('continue'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('continue'));
    await tester.pump();

    expect(allowed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
