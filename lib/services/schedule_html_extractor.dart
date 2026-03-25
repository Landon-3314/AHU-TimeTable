class ScheduleHtmlExtractor {
  const ScheduleHtmlExtractor._();

  static const String academicLoginUrl =
      'https://wvpn.ahu.edu.cn/https/77726476706e69737468656265737421fff944d226387d1e7b0c9ce29b5b/tp_up/view;tp_up=R9Xy9pdDvYVBJP--pNSwF-AmpSF6z3Gxc7qJA89AUuLPNvqwHAtk!-642983885?m=up#act=portal/viewhome';

  static const String extractTimetableHtmlScript = r'''
(function() {
  try {
    function findScheduleTables(doc) {
      if (!doc || !doc.querySelectorAll) {
        return null;
      }
      var found = doc.querySelectorAll('table.Wjkc, table.courseTable');
      return found && found.length > 0 ? found : null;
    }

    var tables = findScheduleTables(document);
    if (!tables) {
      var iframes = document.querySelectorAll('iframe');
      for (var frameIndex = 0; frameIndex < iframes.length; frameIndex += 1) {
        try {
          var iframeDoc = iframes[frameIndex].contentDocument ||
              (iframes[frameIndex].contentWindow && iframes[frameIndex].contentWindow.document);
          var iframeTables = findScheduleTables(iframeDoc);
          if (iframeTables && iframeTables.length > 0) {
            tables = iframeTables;
            break;
          }
        } catch (iframeError) {
          console.error('iframe access error', iframeError);
        }
      }
    }

    if (!tables || tables.length === 0) {
      CourseDataChannel.postMessage("ERROR: 未找到课表表格，请先登录并进入课表页面。");
      return;
    }

    var html = Array.from(tables).map(function(table) {
      return table.outerHTML || '';
    }).join('\n<!--TABLE_SPLIT-->\n');

    if (!html.trim()) {
      CourseDataChannel.postMessage("ERROR: 课表表格为空，无法提取。");
      return;
    }

    CourseDataChannel.postMessage(html);
  } catch (err) {
    CourseDataChannel.postMessage("ERROR: " + ((err && err.message) ? err.message : String(err)));
  }
})();
''';
}
