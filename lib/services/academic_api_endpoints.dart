class AcademicApiEndpoints {
  const AcademicApiEndpoints._();

  static const String academicHost = 'jw.ahu.edu.cn';
  static const String casHost = 'one.ahu.edu.cn';

  static Uri timetablePage() {
    return Uri.https(academicHost, '/student/for-std/course-table');
  }

  static Uri timetablePrintData(int semesterId) {
    return Uri.https(
      academicHost,
      '/student/for-std/course-table/semester/$semesterId/print-data',
      {'semesterId': semesterId.toString(), 'hasExperiment': 'false'},
    );
  }

  static Uri teachWeek() {
    return Uri.https(academicHost, '/student/home/get-current-teach-week');
  }

  static Uri examArrange() {
    return Uri.https(academicHost, '/student/for-std/exam-arrange');
  }

  static Uri gradeSheet() {
    return Uri.https(academicHost, '/student/for-std/grade/sheet');
  }

  static Uri gradeInfo(String studentId) {
    return Uri.https(
      academicHost,
      '/student/for-std/grade/sheet/info/$studentId',
    );
  }
}
