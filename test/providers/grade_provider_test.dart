import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AnKe/models/grade.dart';
import 'package:AnKe/providers/grade_provider.dart';
import 'package:AnKe/services/storage_service.dart';

void main() {
  test('loads cached grades and keeps cache when refresh fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    final provider = GradeProvider(storageService: storage);
    final book = GradeBook(
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
      statistics: const GradeStatistics(
        gpa: 3.86,
        rank: 37,
        rankTotal: 314,
        totalCredits: 114,
        inPlanCredits: 80,
        outPlanCredits: 34,
        updatedAtText: '2026-06-18 23:53',
      ),
      terms: [
        GradeTerm(
          remoteSemesterId: '202520261',
          semesterName: '2025-2026学年秋季学期',
          statistics: const GradeStatistics(
            gpa: 4.2,
            rank: 6,
            totalCredits: 21,
            inPlanCredits: 18,
            outPlanCredits: 3,
          ),
          records: [
            GradeRecord(
              courseCode: 'MATH001',
              courseName: '高等数学',
              credits: 4,
              grade: '95',
              gp: 4,
              courseType: '必修',
              courseProperty: '专业基础课',
              passed: true,
              published: true,
              gradeDetail: '平时:30 期末:65',
              lessonCode: 'MATH001-01',
            ),
          ],
        ),
      ],
    );

    await provider.replaceWithFetched(book);

    final reloaded = GradeProvider(storageService: storage);
    await reloaded.loadCached();

    expect(reloaded.gradeBook?.studentId, '123456');
    expect(reloaded.gradeBook?.statistics?.gpa, 3.86);
    expect(reloaded.gradeBook?.statistics?.rank, 37);
    expect(reloaded.gradeBook?.terms.single.statistics?.gpa, 4.2);
    expect(reloaded.gradeBook?.terms.single.records.single.grade, '95');

    await reloaded.refreshViaWebView(() async {
      throw StateError('network down');
    });

    expect(reloaded.gradeBook?.studentId, '123456');
    expect(reloaded.lastError, contains('network down'));
  });

  test('clears cached grades', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    final provider = GradeProvider(storageService: storage);

    await provider.replaceWithFetched(
      GradeBook(fetchedAt: DateTime(2026, 6, 18), terms: const <GradeTerm>[]),
    );
    await provider.clearCache();

    expect(provider.gradeBook, isNull);
    final reloaded = GradeProvider(storageService: storage);
    await reloaded.loadCached();
    expect(reloaded.gradeBook, isNull);
  });
}
