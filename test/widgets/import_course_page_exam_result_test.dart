import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/screens/import_course_page.dart';

void main() {
  test('exam import result returns empty message when no exams are parsed', () {
    final result = buildExamImportResult(
      hasParsedEvents: false,
      importedCount: 0,
      emptyMessage: 'empty',
      duplicatedMessage: 'duplicated',
    );

    expect(result.kind, AcademicImportKind.exam);
    expect(result.importedCount, 0);
    expect(result.skippedReasons, ['empty']);
  });

  test(
    'exam import result returns duplicated message when nothing new is saved',
    () {
      final result = buildExamImportResult(
        hasParsedEvents: true,
        importedCount: 0,
        emptyMessage: 'empty',
        duplicatedMessage: 'duplicated',
      );

      expect(result.kind, AcademicImportKind.exam);
      expect(result.importedCount, 0);
      expect(result.skippedReasons, ['duplicated']);
    },
  );

  test('exam import result returns imported count when exams are saved', () {
    final result = buildExamImportResult(
      hasParsedEvents: true,
      importedCount: 2,
      emptyMessage: 'empty',
      duplicatedMessage: 'duplicated',
    );

    expect(result.kind, AcademicImportKind.exam);
    expect(result.importedCount, 2);
    expect(result.skippedReasons, isEmpty);
  });

  test(
    'exam import is blocked until timetable import initializes semester',
    () {
      expect(
        buildUninitializedAcademicImportMessage(
          kind: AcademicImportKind.exam,
          isCurrentSemesterInitialized: false,
        ),
        '请先导入课程以自动初始化学期起始日期，再导入考试。',
      );
      expect(
        buildUninitializedAcademicImportMessage(
          kind: AcademicImportKind.timetable,
          isCurrentSemesterInitialized: false,
        ),
        isNull,
      );
      expect(
        buildUninitializedAcademicImportMessage(
          kind: AcademicImportKind.exam,
          isCurrentSemesterInitialized: true,
        ),
        isNull,
      );
    },
  );
}
