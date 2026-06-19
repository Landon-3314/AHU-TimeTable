import 'package:AnKe/models/grade.dart';
import 'package:AnKe/providers/grade_provider.dart';
import 'package:AnKe/services/storage_service.dart';
import 'package:AnKe/widgets/timetable/grade_overview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('grade overview shows summary chips and newest terms first', (
    tester,
  ) async {
    final gradeProvider = await _createGradeProvider(
      GradeBook(
        fetchedAt: DateTime(2026, 6, 19),
        statistics: const GradeStatistics(
          gpa: 3.86,
          rank: 37,
          rankTotal: 314,
          totalCredits: 114,
        ),
        terms: [
          _term('2024-2025-2', '线性代数'),
          _term('2025-2026-1', '大学英语'),
          _term('2025-2026-2', '高等数学'),
        ],
      ),
    );
    addTearDown(gradeProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<GradeProvider>.value(
        value: gradeProvider,
        child: const MaterialApp(home: Scaffold(body: GradeOverviewPanel())),
      ),
    );

    expect(find.text('全程 GPA 3.86'), findsOneWidget);
    expect(find.text('排名 37/314'), findsOneWidget);
    expect(find.text('总学分 114'), findsOneWidget);
    expect(find.text('全程 GPA'), findsNothing);
    expect(find.text('总学分'), findsNothing);

    final textOrder = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    expect(
      textOrder.indexOf('全程成绩'),
      lessThan(textOrder.indexOf('2025-2026-2')),
    );
    expect(
      textOrder.indexOf('2025-2026-2'),
      lessThan(textOrder.indexOf('2025-2026-1')),
    );
    expect(
      textOrder.indexOf('2025-2026-1'),
      lessThan(textOrder.indexOf('2024-2025-2')),
    );
  });
}

Future<GradeProvider> _createGradeProvider(GradeBook book) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final gradeProvider = GradeProvider(
    storageService: StorageService(sharedPreferences: preferences),
  );
  await gradeProvider.replaceWithFetched(book);
  return gradeProvider;
}

GradeTerm _term(String semesterName, String courseName) {
  return GradeTerm(
    remoteSemesterId: semesterName,
    semesterName: semesterName,
    records: [
      GradeRecord(
        courseCode: courseName,
        courseName: courseName,
        credits: 2,
        grade: '90',
      ),
    ],
  );
}
