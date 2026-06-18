import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/academic_credential.dart';
import 'package:AnKe/services/academic_auto_login_service.dart';
import 'package:AnKe/services/schedule_html_extractor.dart';

void main() {
  test('builds unified portal login script with escaped credentials', () {
    const credential = AcademicCredential(
      studentId: "G12'34\\56\n78",
      password: "pa'ss\\word\n!",
      autoLoginEnabled: true,
    );

    final script = AcademicAutoLoginService.buildUnifiedPortalLoginScript(
      credential,
    );

    expect(script, contains(jsonEncode(credential.studentId)));
    expect(script, contains(jsonEncode(credential.password)));
    expect(
      script,
      contains('let password = ${jsonEncode(credential.password)};'),
    );
    expect(script, contains('password = null;'));
    expect(script, contains('#un'));
    expect(script, contains('#pd'));
    expect(script, contains('#username'));
    expect(script, contains('input[name="username"]'));
    expect(script, contains('input[type="password"]'));
    expect(script, contains('#index_login_btn'));
    expect(script, contains('button[type="submit"]'));
    expect(script, contains('[role="button"]'));
    expect(script, contains('[onclick*="login" i]'));
    expect(script, contains('登录'));
    expect(script, contains('登 录'));
    expect(script, contains('window.login()'));
    expect(script, contains('SUBMITTED'));
    expect(script, contains('CHALLENGE_REQUIRED'));
    expect(script, isNot(contains("studentId = '${credential.studentId}'")));
    expect(script, isNot(contains("password = '${credential.password}'")));
  });

  test('only allows explicit academic import hosts', () {
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('https://ahu.edu.cn'),
      ),
      isTrue,
    );
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('https://jw.ahu.edu.cn/student/home'),
      ),
      isTrue,
    );
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('https://one.ahu.edu.cn/cas/login'),
      ),
      isTrue,
    );
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('https://wvpn.ahu.edu.cn'),
      ),
      isTrue,
    );
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('https://takeover.ahu.edu.cn'),
      ),
      isFalse,
    );
    expect(
      AcademicAutoLoginService.isAllowedAcademicUri(
        Uri.parse('http://jw.ahu.edu.cn/student/home'),
      ),
      isFalse,
    );
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
        Uri.parse('https://jw.ahu.edu.cn/student/sso/login'),
      ),
      AcademicPageKind.jwSsoLogin,
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
      AcademicAutoLoginService.classifyUrl(
        Uri.parse('${ScheduleHtmlExtractor.academicExamUrl}/info/99358'),
      ),
      AcademicPageKind.exam,
    );
    expect(
      AcademicAutoLoginService.classifyUrl(Uri.parse('https://example.com')),
      AcademicPageKind.other,
    );
  });
}
