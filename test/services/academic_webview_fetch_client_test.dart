import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/academic_webview_fetch_client.dart';

void main() {
  test('detects CAS redirect as login expired', () {
    const response = AcademicFetchResponse(
      requestId: 'request-1',
      ok: true,
      status: 200,
      redirected: true,
      url: 'https://one.ahu.edu.cn/cas/login?service=x',
      contentType: 'text/html',
      body: '<html></html>',
    );

    expect(response.isLoginExpired, isTrue);
  });

  test('detects login page body as login expired', () {
    const response = AcademicFetchResponse(
      requestId: 'request-2',
      ok: true,
      status: 200,
      redirected: false,
      url: 'https://jw.ahu.edu.cn/student/for-std/exam-arrange',
      contentType: 'text/html',
      body: '<form id="casLoginForm">统一身份认证</form>',
    );

    expect(response.isLoginExpired, isTrue);
  });
}
