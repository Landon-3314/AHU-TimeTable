import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/academic_credential.dart';
import 'package:timetable/services/academic_auto_login_service.dart';
import 'package:timetable/services/schedule_html_extractor.dart';

void main() {
  test('builds login script with json escaped credentials and selectors', () {
    const credential = AcademicCredential(
      studentId: "G12'34\\56\n78",
      password: "pa'ss\\word\n!",
      autoLoginEnabled: true,
    );

    final script = AcademicAutoLoginService.buildLoginScript(credential);

    expect(script, contains(jsonEncode(credential.studentId)));
    expect(script, contains(jsonEncode(credential.password)));
    expect(script, contains('#username'));
    expect(script, contains('input[name="username"]'));
    expect(script, contains('用户名'));
    expect(script, contains('密码'));
    expect(script, contains('账号登录'));
    expect(script, contains('登录'));
    expect(script, contains('SWITCHED_LOGIN_TAB'));
    expect(script, contains('input[type="password"]'));
    expect(script, contains('button[type="submit"]'));
    expect(script, isNot(contains("studentId = '${credential.studentId}'")));
    expect(script, isNot(contains("password = '${credential.password}'")));
  });

  test('provides exam ready and refresh scripts for exam extraction', () {
    expect(AcademicAutoLoginService.examReadyScript, contains('#exams'));
    expect(
      AcademicAutoLoginService.examReadyScript,
      contains('table.exam-table'),
    );
    expect(AcademicAutoLoginService.examRefreshScript, contains('考试信息查询'));
    expect(AcademicAutoLoginService.examRefreshScript, contains('刷新'));
  });

  test('classifies academic urls for the auto import state machine', () {
    expect(
      AcademicAutoLoginService.classifyUrl(
        Uri.parse(ScheduleHtmlExtractor.academicCasLoginUrl),
      ),
      AcademicPageKind.casLogin,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(
        Uri.parse(
          'https://jw.ahu.edu.cn/student/login?refer=https://jw.ahu.edu.cn/student/for-std/course-table',
        ),
      ),
      AcademicPageKind.jwLogin,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(
        Uri.parse('https://jw.ahu.edu.cn/student/home'),
      ),
      AcademicPageKind.studentHome,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(
        Uri.parse(ScheduleHtmlExtractor.academicTimetableUrl),
      ),
      AcademicPageKind.timetable,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(
        Uri.parse(ScheduleHtmlExtractor.academicExamUrl),
      ),
      AcademicPageKind.exam,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(Uri.parse('https://example.com')),
      AcademicPageKind.other,
    );
  });
}
