import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/widgets/common/app_ui.dart';

void main() {
  testWidgets('showAppSnackBar replaces the visible snack bar immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  FilledButton(
                    onPressed: () {
                      showAppSnackBar(
                        context,
                        const SnackBar(content: Text('第一次提示')),
                      );
                    },
                    child: const Text('first'),
                  ),
                  FilledButton(
                    onPressed: () {
                      showAppSnackBar(
                        context,
                        const SnackBar(content: Text('第二次提示')),
                      );
                    },
                    child: const Text('second'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('first'));
    await tester.pump();
    expect(find.text('第一次提示'), findsOneWidget);

    await tester.tap(find.text('second'));
    await tester.pump();
    expect(find.text('第一次提示'), findsNothing);
    expect(find.text('第二次提示'), findsOneWidget);
  });
}
