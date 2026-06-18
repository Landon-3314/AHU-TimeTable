import 'dart:convert';

import '../models/academic_credential.dart';

enum AcademicPageKind {
  casLogin,
  jwLogin,
  jwSsoLogin,
  studentHome,
  timetable,
  exam,
  other,
}

class AcademicAutoLoginService {
  const AcademicAutoLoginService._();

  static const Set<String> allowedAcademicHosts = <String>{
    'ahu.edu.cn',
    'jw.ahu.edu.cn',
    'one.ahu.edu.cn',
    'wvpn.ahu.edu.cn',
  };

  static bool isAllowedAcademicUri(Uri uri) {
    if (uri.scheme != 'https') {
      return false;
    }
    return allowedAcademicHosts.contains(uri.host.toLowerCase());
  }

  static AcademicPageKind classifyUrl(Uri? uri) {
    if (uri == null || uri.scheme != 'https') {
      return AcademicPageKind.other;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'one.ahu.edu.cn' && path.contains('/cas/login')) {
      return AcademicPageKind.casLogin;
    }
    if (host == 'jw.ahu.edu.cn' && path == '/student/login') {
      return AcademicPageKind.jwLogin;
    }
    if (host == 'jw.ahu.edu.cn' && path == '/student/sso/login') {
      return AcademicPageKind.jwSsoLogin;
    }
    if (host == 'jw.ahu.edu.cn' && path == '/student/home') {
      return AcademicPageKind.studentHome;
    }
    if (host == 'jw.ahu.edu.cn' && path == '/student/for-std/course-table') {
      return AcademicPageKind.timetable;
    }
    if (host == 'jw.ahu.edu.cn' &&
        path.startsWith('/student/for-std/exam-arrange')) {
      return AcademicPageKind.exam;
    }
    return AcademicPageKind.other;
  }

  static String buildUnifiedPortalLoginScript(AcademicCredential credential) {
    final studentId = jsonEncode(credential.studentId);
    final password = jsonEncode(credential.password);
    return '''
(function() {
  try {
    const studentId = $studentId;
    let password = $password;
    const usernameSelectors = [
      '#un',
      '#username',
      'input[name="username"]',
      'input[name="userName"]',
      'input[name="loginName"]',
      'input[name="account"]',
      'input[placeholder="用户名"]',
      'input[placeholder*="账号"]',
      'input[placeholder*="学号"]',
      'input[type="text"]'
    ];
    const passwordSelectors = [
      '#pd',
      '#password',
      'input[name="password"]',
      'input[placeholder="密码"]',
      'input[type="password"]'
    ];
    const submitSelectors = [
      '#index_login_btn',
      '.login_box_landing_btn',
      'button[type="submit"]',
      'input[type="submit"]',
      '[role="button"]',
      '[onclick*="login" i]',
      '[class*="login" i]',
      '.login-btn',
      '#login',
      '#loginButton'
    ];
    const challengeSelectors = [
      'input[name*="captcha" i]',
      'input[id*="captcha" i]',
      'input[name*="code" i]',
      'input[id*="code" i]',
      '.captcha',
      '.verify',
      '.slider'
    ];

    function isVisible(element) {
      if (!element) {
        return false;
      }
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' &&
        style.visibility !== 'hidden' &&
        rect.width > 0 &&
        rect.height > 0;
    }

    function firstVisible(selectors) {
      for (const selector of selectors) {
        const nodes = Array.from(document.querySelectorAll(selector));
        const visible = nodes.find(isVisible);
        if (visible) {
          return visible;
        }
      }
      return null;
    }

    function firstVisibleButtonByText(labels) {
      const nodes = Array.from(document.querySelectorAll('button,input[type="button"],input[type="submit"],a'));
      return nodes.find(function(node) {
        if (!isVisible(node)) {
          return false;
        }
        const text = (node.innerText || node.value || node.textContent || '').trim();
        return labels.some(function(label) {
          return text === label || text.indexOf(label) !== -1;
        });
      }) || null;
    }

    if (firstVisible(challengeSelectors)) {
      return 'CHALLENGE_REQUIRED';
    }

    const username = firstVisible(usernameSelectors);
    const passwordInput = firstVisible(passwordSelectors);
    if (!username || !passwordInput) {
      return 'MISSING_FORM';
    }

    username.focus();
    username.value = studentId;
    username.dispatchEvent(new Event('input', { bubbles: true }));
    username.dispatchEvent(new Event('change', { bubbles: true }));
    if (window.jQuery) {
      window.jQuery(username).val(studentId).trigger('input').trigger('change');
    }

    passwordInput.focus();
    passwordInput.value = password;
    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
    if (window.jQuery) {
      window.jQuery(passwordInput).val(password).trigger('input').trigger('change');
    }
    password = null;

    if (typeof window.login === 'function') {
      window.login();
      return 'SUBMITTED';
    }

    const submit =
      firstVisible(submitSelectors) ||
      firstVisibleButtonByText(['立即登录', '登录', '登 录']);
    if (!submit) {
      return 'MISSING_SUBMIT';
    }
    submit.click();
    return 'SUBMITTED';
  } catch (error) {
    return 'JS_ERROR: ' + (error && error.message ? error.message : String(error));
  }
})();
''';
  }

  static const String timetableReadyScript = r'''
(function() {
  try {
    const visited = [];
    function collect(targetWindow, bucket) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);
      let frameCount = 0;
      try {
        frameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (_) {
        // Cross-origin frames can deny access; keep scanning reachable windows.
        frameCount = 0;
      }
      for (let index = 0; index < frameCount; index += 1) {
        try {
          collect(targetWindow.frames[index], bucket);
        } catch (_) {
          // Cross-origin child frames are skipped intentionally.
        }
      }
    }

    const windows = [];
    collect(window, windows);
    for (const currentWindow of windows) {
      try {
        const doc = currentWindow.document;
        if (doc && doc.querySelector('table.courseTable, table.Wjkc')) {
          return 'READY';
        }
      } catch (_) {
        // Cross-origin frames cannot expose document; ignore that frame only.
      }
    }
    return 'NOT_READY';
  } catch (error) {
    return 'JS_ERROR: ' + (error && error.message ? error.message : String(error));
  }
})();
''';

  static const String examReadyScript = r'''
(function() {
  try {
    const visited = [];
    function collect(targetWindow, bucket) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);
      let frameCount = 0;
      try {
        frameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (_) {
        // Cross-origin frames can deny access; keep scanning reachable windows.
        frameCount = 0;
      }
      for (let index = 0; index < frameCount; index += 1) {
        try {
          collect(targetWindow.frames[index], bucket);
        } catch (_) {
          // Cross-origin child frames are skipped intentionally.
        }
      }
    }

    const windows = [];
    collect(window, windows);
    for (const currentWindow of windows) {
      try {
        const doc = currentWindow.document;
        if (doc && doc.querySelector('#exams, table.exam-table')) {
          return 'READY';
        }
      } catch (_) {
        // Cross-origin frames cannot expose document; ignore that frame only.
      }
    }
    return 'NOT_READY';
  } catch (error) {
    return 'JS_ERROR: ' + (error && error.message ? error.message : String(error));
  }
})();
''';

  static const String examRefreshScript = r'''
(function() {
  try {
    const iframe = document.querySelector('iframe[src*="/student/for-std/exam-arrange"]');
    const activeExamLink = Array.from(document.querySelectorAll('a,span,div,li'))
      .some(function(node) {
        const text = (node.innerText || node.textContent || '').trim();
        return text.indexOf('考试信息查询') !== -1;
      });
    if (!iframe && !activeExamLink) {
      return 'NOT_EXAM_PAGE';
    }

    const buttons = Array.from(document.querySelectorAll('button,a,[role="button"]'));
    const refresh = buttons.find(function(node) {
      const style = window.getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      const visible = style.display !== 'none' &&
        style.visibility !== 'hidden' &&
        rect.width > 0 &&
        rect.height > 0;
      const text = (node.innerText || node.textContent || '').trim();
      return visible && text === '刷新';
    });
    if (!refresh) {
      return 'MISSING_REFRESH';
    }
    refresh.click();
    return 'REFRESH_CLICKED';
  } catch (error) {
    return 'JS_ERROR: ' + (error && error.message ? error.message : String(error));
  }
})();
''';
}
