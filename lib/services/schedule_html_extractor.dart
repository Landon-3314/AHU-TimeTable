class ScheduleHtmlExtractor {
  const ScheduleHtmlExtractor._();

  static const String academicLoginUrl =
      'https://wvpn.ahu.edu.cn/https/77726476706e69737468656265737421fff944d226387d1e7b0c9ce29b5b/tp_up/view;tp_up=R9Xy9pdDvYVBJP--pNSwF-AmpSF6z3Gxc7qJA89AUuLPNvqwHAtk!-642983885?m=up#act=portal/viewhome';

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

  static const String extractExamHtmlScript = r'''
(function() {
  return 'ERROR: Exam extraction is not implemented yet.';
})();
''';
}
