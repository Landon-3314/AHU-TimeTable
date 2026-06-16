import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AnKe/services/corrupt_row_diagnostic_store.dart';

void main() {
  test('records corrupt rows and consumes pending notice count once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CorruptRowDiagnosticStore(
      sharedPreferences: preferences,
      clock: () => DateTime.utc(2026, 6, 1, 8),
    );

    final added = await store.recordAll([
      const CorruptRowDiagnosticCandidate(
        sourceKey: 'semesters.s1.events.items',
        rawValue: '{broken',
        reason: 'invalid_event_row',
      ),
    ]);

    expect(added, 1);
    expect(store.loadRecords(), [
      CorruptRowDiagnosticRecord(
        sourceKey: 'semesters.s1.events.items',
        rawValue: '{broken',
        reason: 'invalid_event_row',
        detectedAt: DateTime.utc(2026, 6, 1, 8),
      ),
    ]);
    expect(await store.consumePendingCount(), 1);
    expect(await store.consumePendingCount(), 0);
  });

  test('does not duplicate the same corrupt source row', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CorruptRowDiagnosticStore(sharedPreferences: preferences);
    const candidate = CorruptRowDiagnosticCandidate(
      sourceKey: 'semesters.s1.courses.items',
      rawValue: '{broken',
      reason: 'invalid_course_row',
    );

    expect(await store.recordAll([candidate]), 1);
    expect(await store.recordAll([candidate]), 0);

    expect(store.loadRecords(), hasLength(1));
    expect(await store.consumePendingCount(), 1);
  });

  test('keeps the newest one hundred corrupt rows', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CorruptRowDiagnosticStore(sharedPreferences: preferences);

    await store.recordAll([
      for (var index = 0; index < 105; index += 1)
        CorruptRowDiagnosticCandidate(
          sourceKey: 'semesters.s1.events.items',
          rawValue: 'broken-$index',
          reason: 'invalid_event_row',
        ),
    ]);

    final records = store.loadRecords();
    expect(records, hasLength(100));
    expect(records.first.rawValue, 'broken-5');
    expect(records.last.rawValue, 'broken-104');
    expect(await store.consumePendingCount(), 105);
  });
}
