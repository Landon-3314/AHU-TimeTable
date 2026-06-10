import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/screens/import_course_page.dart';

void main() {
  test(
    'auto import retry policy treats transient page loading as recoverable',
    () {
      expect(isRecoverableAcademicAutoImportError('等待统一门户登录或教务页面加载超时'), isTrue);
      expect(
        isRecoverableAcademicAutoImportError('统一登录门户未找到登录按钮，请手动打开教务页面登录后重试。'),
        isTrue,
      );
      expect(
        isRecoverableAcademicAutoImportError('教务系统连接失败，请检查网络或重新登录后重试。'),
        isTrue,
      );
    },
  );

  test('auto import retry policy does not retry user-action failures', () {
    expect(isRecoverableAcademicAutoImportError('检测到验证码或二次验证，需要手动完成'), isFalse);
    expect(isRecoverableAcademicAutoImportError('请先填写学号和密码。'), isFalse);
  });
}
