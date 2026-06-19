import 'package:AnKe/models/grade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grade statistics keeps preferred values and fills missing fields', () {
    const pageStats = GradeStatistics(gpa: 3.86, rank: 37);
    const apiStats = GradeStatistics(
      gpa: 3.5,
      rank: 2,
      rankTotal: 314,
      totalCredits: 114,
    );

    final merged = pageStats.fillMissingFrom(apiStats);

    expect(merged.gpa, 3.86);
    expect(merged.rank, 37);
    expect(merged.rankTotal, 314);
    expect(merged.totalCredits, 114);
  });
}
