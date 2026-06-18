enum AcademicImportKind { timetable, exam }

enum AcademicAutoAction { timetable, exam }

class AcademicImportResult {
  const AcademicImportResult({
    required this.kind,
    required this.importedCount,
    this.skippedReasons = const <String>[],
  });

  final AcademicImportKind kind;
  final int importedCount;
  final List<String> skippedReasons;

  int get skippedCount => skippedReasons.length;
}

AcademicImportResult buildExamImportResult({
  required bool hasParsedEvents,
  required int importedCount,
  required String emptyMessage,
  required String duplicatedMessage,
}) {
  if (!hasParsedEvents) {
    return AcademicImportResult(
      kind: AcademicImportKind.exam,
      importedCount: 0,
      skippedReasons: <String>[emptyMessage],
    );
  }

  if (importedCount == 0) {
    return AcademicImportResult(
      kind: AcademicImportKind.exam,
      importedCount: 0,
      skippedReasons: <String>[duplicatedMessage],
    );
  }

  return AcademicImportResult(
    kind: AcademicImportKind.exam,
    importedCount: importedCount,
  );
}

String? buildUninitializedAcademicImportMessage({
  required AcademicImportKind kind,
  required bool isCurrentSemesterInitialized,
}) {
  if (isCurrentSemesterInitialized || kind == AcademicImportKind.timetable) {
    return null;
  }
  return '请先导入课程以自动初始化学期起始日期，再导入考试。';
}

bool isRecoverableAcademicAutoImportError(String message) {
  final normalized = message.toLowerCase();
  const userActionRequiredIndicators = <String>[
    '验证码',
    '二次验证',
    'captcha',
    'second verification',
    '请先填写学号和密码',
    'student id and password',
    '账号或密码',
    '用户名或密码',
    '密码错误',
    'invalid credential',
    'incorrect password',
  ];
  if (userActionRequiredIndicators.any(normalized.contains)) {
    return false;
  }

  const transientIndicators = <String>[
    '超时',
    'timed out',
    '未找到登录按钮',
    'login button was not found',
    '连接失败',
    'connection failed',
    'network',
    '重新登录',
  ];
  return transientIndicators.any(normalized.contains);
}
