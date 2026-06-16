import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/event.dart';

void main() {
  test('event json rejects missing date time', () {
    expect(
      () => Event.fromJson({
        'name': 'Exam',
        'location': 'Room 101',
        'enableAlarm': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('event json rejects non-string date time', () {
    expect(
      () => Event.fromJson({
        'name': 'Exam',
        'location': 'Room 101',
        'dateTime': 42,
        'enableAlarm': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('event json rejects malformed date time', () {
    expect(
      () => Event.fromJson({
        'name': 'Exam',
        'location': 'Room 101',
        'dateTime': 'not-a-date',
        'enableAlarm': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('event json preserves nullable imported time', () {
    final importedAt = DateTime(2026, 6, 1, 10, 30);
    final event = Event(
      name: '考试',
      location: 'A101',
      dateTime: DateTime(2026, 6, 8, 9),
      enableAlarm: true,
      importedAt: importedAt,
    );

    expect(Event.fromJson(event.toJson()).importedAt, importedAt);
    expect(
      Event.fromJson({...event.toJson(), 'importedAt': 'broken'}).importedAt,
      isNull,
    );
    expect(
      Event.fromJson({...event.toJson()}..remove('importedAt')).importedAt,
      isNull,
    );
  });
}
