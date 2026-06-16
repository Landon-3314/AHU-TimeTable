class ScheduleHtmlExtractor {
  const ScheduleHtmlExtractor._();

  static final RegExp _datePattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');

  static const String academicLoginUrl =
      'https://wvpn.ahu.edu.cn/https/77726476706e69737468656265737421fff944d226387d1e7b0c9ce29b5b/tp_up/view;tp_up=R9Xy9pdDvYVBJP--pNSwF-AmpSF6z3Gxc7qJA89AUuLPNvqwHAtk!-642983885?m=up#act=portal/viewhome';

  static const String academicTimetableUrl =
      'https://jw.ahu.edu.cn/student/for-std/course-table';

  static const String academicExamUrl =
      'https://jw.ahu.edu.cn/student/for-std/exam-arrange';

  static const String academicCasLoginUrl =
      'https://one.ahu.edu.cn/cas/login?service=https%3A%2F%2Fjw.ahu.edu.cn%2Fstudent%2Fsso%2Flogin';

  static DateTime? parseSemesterStartDate(String rawTextOrHtml) {
    final trimmed = rawTextOrHtml.trim();
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(trimmed)) {
      return _parseDate(trimmed);
    }

    final startDateElementMatch = RegExp(
      r'''<[^>]*\bid\s*=\s*["']startDate["'][^>]*>(.*?)</[^>]+>''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(rawTextOrHtml);
    final fromStartDateElement = _parseDate(
      startDateElementMatch?.group(1) ?? '',
    );
    if (fromStartDateElement != null) {
      return fromStartDateElement;
    }

    final normalizedText = rawTextOrHtml.replaceAll('&nbsp;', ' ');
    final labelMatch = RegExp(
      r'学期\s*起始\s*日期\s*[:：]\s*(\d{4}-\d{1,2}-\d{1,2})',
    ).firstMatch(normalizedText);
    return _parseDate(labelMatch?.group(1) ?? '');
  }

  static DateTime? _parseDate(String value) {
    final match = _datePattern.firstMatch(value);
    if (match == null) {
      return null;
    }

    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    if (year == null || month == null || day == null) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static const String extractTimetableHtmlScript = r'''
(function() {
  try {
    function formatError(prefix, error) {
      var detail = '';
      try {
        detail = error && error.message ? error.message : String(error);
      } catch (_) {
        detail = 'unknown error';
      }
      return prefix + ': ' + detail;
    }

    function collectWindows(targetWindow, bucket, visited, errors) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);

      var childFrameCount = 0;
      try {
        childFrameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (frameCountError) {
        errors.push(formatError('FRAME_COUNT_ERROR', frameCountError));
        childFrameCount = 0;
      }

      for (var index = 0; index < childFrameCount; index += 1) {
        try {
          collectWindows(targetWindow.frames[index], bucket, visited, errors);
        } catch (frameError) {
          errors.push(formatError('FRAME_TRAVERSAL_ERROR', frameError));
        }
      }
    }

    function extractCandidateHtml(doc) {
      if (!doc || !doc.querySelectorAll) {
        return '';
      }

      var tables = doc.querySelectorAll('table.Wjkc, table.courseTable');
      if (tables && tables.length > 0) {
        return Array.from(tables).map(function(table) {
          return table.outerHTML || '';
        }).join('\n<!--TABLE_SPLIT-->\n');
      }

      var richNodes = doc.querySelectorAll(
        '.tdHtml, td.td-content, .course-name, .Wjkc, .courseTable'
      );
      if (richNodes && richNodes.length > 0) {
        if (doc.documentElement && doc.documentElement.innerHTML) {
          return doc.documentElement.innerHTML;
        }
        if (doc.body && doc.body.innerHTML) {
          return doc.body.innerHTML;
        }
      }

      return '';
    }

    var windows = [];
    var jsErrors = [];
    collectWindows(window, windows, [], jsErrors);

    var fragments = [];
    for (var windowIndex = 0; windowIndex < windows.length; windowIndex += 1) {
      try {
        var currentWindow = windows[windowIndex];
        var currentDoc = currentWindow.document;
        var extracted = extractCandidateHtml(currentDoc);
        if (extracted && extracted.trim()) {
          fragments.push(extracted);
        }
      } catch (documentError) {
        jsErrors.push(formatError('DOCUMENT_EXTRACTION_ERROR', documentError));
      }
    }

    if (fragments.length === 0) {
      if (jsErrors.length > 0) {
        return 'JS_ERROR: ' + jsErrors.join(' | ');
      }
      return 'ERROR: No timetable table was detected. Open the timetable page first.';
    }

    var html = Array.from(new Set(fragments)).join('\n<!--DOCUMENT_SPLIT-->\n');
    if (!html.trim()) {
      return 'ERROR: Timetable HTML was empty.';
    }

    return html;
  } catch (error) {
    return 'JS_ERROR: ' +
      (error && error.message ? error.message : String(error));
  }
})();
''';

  static const String extractSemesterStartDateScript = r'''
(function() {
  try {
    function formatError(prefix, error) {
      var detail = '';
      try {
        detail = error && error.message ? error.message : String(error);
      } catch (_) {
        detail = 'unknown error';
      }
      return prefix + ': ' + detail;
    }

    function collectWindows(targetWindow, bucket, visited, errors) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);

      var childFrameCount = 0;
      try {
        childFrameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (frameCountError) {
        errors.push(formatError('FRAME_COUNT_ERROR', frameCountError));
        childFrameCount = 0;
      }

      for (var index = 0; index < childFrameCount; index += 1) {
        try {
          collectWindows(targetWindow.frames[index], bucket, visited, errors);
        } catch (frameError) {
          errors.push(formatError('FRAME_TRAVERSAL_ERROR', frameError));
        }
      }
    }

    function extractStartDate(doc) {
      if (!doc || !doc.querySelector) {
        return '';
      }

      var startDate = doc.querySelector('#startDate');
      if (startDate && startDate.textContent) {
        var directValue = startDate.textContent.trim();
        if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(directValue)) {
          return directValue;
        }
      }

      var bodyText = doc.body ? (doc.body.innerText || doc.body.textContent || '') : '';
      var labelMatch = bodyText.match(/学期\s*起始\s*日期\s*[:：]\s*(\d{4}-\d{1,2}-\d{1,2})/);
      return labelMatch ? labelMatch[1] : '';
    }

    var windows = [];
    var jsErrors = [];
    collectWindows(window, windows, [], jsErrors);

    for (var windowIndex = 0; windowIndex < windows.length; windowIndex += 1) {
      try {
        var currentWindow = windows[windowIndex];
        var extracted = extractStartDate(currentWindow.document);
        if (extracted) {
          return extracted;
        }
      } catch (documentError) {
        jsErrors.push(formatError('DOCUMENT_EXTRACTION_ERROR', documentError));
      }
    }

    if (jsErrors.length > 0) {
      return 'JS_ERROR: ' + jsErrors.join(' | ');
    }
    return 'ERROR: No semester start date was detected. Open the timetable page first.';
  } catch (error) {
    return 'JS_ERROR: ' +
      (error && error.message ? error.message : String(error));
  }
})();
''';

  static const String extractExamHtmlScript = r'''
(function() {
  try {
    function formatError(prefix, error) {
      var detail = '';
      try {
        detail = error && error.message ? error.message : String(error);
      } catch (_) {
        detail = 'unknown error';
      }
      return prefix + ': ' + detail;
    }

    function collectWindows(targetWindow, bucket, visited, errors) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);

      var childFrameCount = 0;
      try {
        childFrameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (frameCountError) {
        errors.push(formatError('FRAME_COUNT_ERROR', frameCountError));
        childFrameCount = 0;
      }

      for (var index = 0; index < childFrameCount; index += 1) {
        try {
          collectWindows(targetWindow.frames[index], bucket, visited, errors);
        } catch (frameError) {
          errors.push(formatError('FRAME_TRAVERSAL_ERROR', frameError));
        }
      }
    }

    function extractExamHtml(doc) {
      if (!doc || !doc.querySelectorAll) {
        return '';
      }

      var table =
        doc.querySelector('table.exam-table#exams') ||
        doc.querySelector('table#exams') ||
        doc.querySelector('#exams') ||
        doc.querySelector('table.exam-table');
      if (table && table.outerHTML) {
        return table.outerHTML;
      }

      var rows = doc.querySelectorAll('tr.unfinished');
      if (rows && rows.length > 0) {
        return '<table id="exams" class="exam-table"><tbody>' +
          Array.from(rows).map(function(row) {
            return row.outerHTML || '';
          }).join('') +
          '</tbody></table>';
      }

      return '';
    }

    var windows = [];
    var jsErrors = [];
    collectWindows(window, windows, [], jsErrors);

    var fragments = [];
    for (var windowIndex = 0; windowIndex < windows.length; windowIndex += 1) {
      try {
        var currentWindow = windows[windowIndex];
        var currentDoc = currentWindow.document;
        var extracted = extractExamHtml(currentDoc);
        if (extracted && extracted.trim()) {
          fragments.push(extracted);
        }
      } catch (documentError) {
        jsErrors.push(formatError('DOCUMENT_EXTRACTION_ERROR', documentError));
      }
    }

    if (fragments.length === 0) {
      if (jsErrors.length > 0) {
        return 'JS_ERROR: ' + jsErrors.join(' | ');
      }
      return 'ERROR: No exam table was detected. Open the exam page first.';
    }

    var html = Array.from(new Set(fragments)).join('\n<!--DOCUMENT_SPLIT-->\n');
    if (!html.trim()) {
      return 'ERROR: Exam HTML was empty.';
    }

    return html;
  } catch (error) {
    return 'JS_ERROR: ' +
      (error && error.message ? error.message : String(error));
  }
})();
''';
}
