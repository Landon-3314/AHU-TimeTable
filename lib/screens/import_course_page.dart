import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/course.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';

const String academicLoginUrl =
    'https://wvpn.ahu.edu.cn/https/77726476706e69737468656265737421fff944d226387d1e7b0c9ce29b5b/tp_up/view;tp_up=R9Xy9pdDvYVBJP--pNSwF-AmpSF6z3Gxc7qJA89AUuLPNvqwHAtk!-642983885?m=up#act=portal/viewhome';

const String extractScript = r'''
(function() {
  try {
    CourseDataChannel.postMessage("DEBUG: 脚本已启动...");

    function findScheduleTables(doc) {
      if (!doc || !doc.querySelectorAll) {
        return null;
      }
      var found = doc.querySelectorAll('table.Wjkc, table.courseTable');
      return found && found.length > 0 ? found : null;
    }

    function getCleanText(node) {
      if (!node) {
        return '';
      }

      var clone = node.cloneNode(true);
      clone.querySelectorAll(
        'script, style, .tag-info, [style*="display:none"], [style*="display: none"]',
      ).forEach(function(hiddenNode) {
        hiddenNode.remove();
      });

      var html = clone.innerHTML || '';
      html = html.replace(/<hr\s*\/?>/gi, '\n---COURSE-SPLIT---\n');
      html = html.replace(/<br\s*\/?>/gi, '\n');

      var container = document.createElement('div');
      container.innerHTML = html;

      return String(container.innerText || container.textContent || '')
        .replace(/\u00a0/g, ' ')
        .replace(/[ \t]+/g, ' ')
        .replace(/\n\s+\n/g, '\n')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
    }

    function hashString(source) {
      var hash = 0;
      var text = String(source || '');
      for (var i = 0; i < text.length; i += 1) {
        hash = ((hash << 5) - hash) + text.charCodeAt(i);
        hash |= 0;
      }
      return Math.abs(hash);
    }

    function pickColor(seed) {
      var palette = [
        0xFF7C9AF2,
        0xFF56C8B4,
        0xFF6FB0F3,
        0xFFF0C86D,
        0xFFF49060,
        0xFFA9CE95,
        0xFFD2A1F2,
        0xFF9AA6BD
      ];
      return palette[hashString(seed) % palette.length];
    }

    function expandWeeks(start, end) {
      var from = Number(start);
      var to = Number(end == null ? start : end);
      if (!Number.isFinite(from) || !Number.isFinite(to)) {
        return [1];
      }

      var result = [];
      for (var i = from; i <= to; i += 1) {
        result.push(i);
      }
      return result;
    }

    function parseWeeks(detailText) {
      var text = String(detailText || '');
      var match = text.match(/(\d{1,2})\s*[~-]\s*(\d{1,2})\s*周(?:\((单|双)\))?/);
      if (!match) {
        match = text.match(/(\d{1,2})\s*周(?:\((单|双)\))?/);
      }

      if (!match) {
        return [1];
      }

      var start = Number(match[1]);
      var end = match[2] ? Number(match[2]) : start;
      var weeks = expandWeeks(start, end);
      var oddEven = match[3] || '';

      if (oddEven === '单') {
        weeks = weeks.filter(function(week) { return week % 2 === 1; });
      } else if (oddEven === '双') {
        weeks = weeks.filter(function(week) { return week % 2 === 0; });
      }

      return weeks.length > 0 ? weeks : [1];
    }

    function parseLocationAndTeacher(detailText) {
      var text = String(detailText || '')
        .replace(/^\s*\(?\d{1,2}(?:\s*[~-]\s*\d{1,2})?\s*周(?:\((?:单|双)\))?\s*/g, '')
        .replace(/^\s*\(?\d{1,2}(?:\s*[~-]\s*\d{1,2})?\s*节\s*/g, '')
        .replace(/\d{1,2}\s*[~-]\s*\d{1,2}\s*周(?:\((?:单|双)\))?/g, '')
        .replace(/\d{1,2}\s*[~-]\s*\d{1,2}\s*节/g, '')
        .replace(/\d{1,2}\s*周(?:\((?:单|双)\))?/g, '')
        .replace(/[()]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

      var tailMatch = text.match(/(.+?)\s+([^\s()（）]+(?:\/[^\s()（）]+)*)$/);
      if (!tailMatch) {
        return {
          location: text,
          teacher: '',
        };
      }

      return {
        location: String(tailMatch[1] || '').trim(),
        teacher: String(tailMatch[2] || '').trim(),
      };
    }

    function splitCourseBlocks(tdHtml) {
      var blocks = [];
      var current = [];
      var children = Array.from((tdHtml && tdHtml.children) || []);

      children.forEach(function(child) {
        if (!child) {
          return;
        }

        if (child.tagName === 'HR') {
          if (current.length > 0) {
            blocks.push(current.slice());
            current = [];
          }
          return;
        }

        if (child.classList && child.classList.contains('course-name') && current.length > 0) {
          blocks.push(current.slice());
          current = [];
        }

        current.push(child);
      });

      if (current.length > 0) {
        blocks.push(current);
      }

      return blocks;
    }

    function parseBlock(blockNodes, weekday, startPeriod, endPeriod) {
      var nameNode = blockNodes.find(function(node) {
        return node && node.classList && node.classList.contains('course-name');
      });

      var detailNode = blockNodes.find(function(node) {
        return node &&
          (!node.classList || !node.classList.contains('course-name')) &&
          (!node.classList || !node.classList.contains('lesson-name')) &&
          /周|节|\d+\s*[~-]\s*\d+/.test(getCleanText(node));
      });

      var name = getCleanText(nameNode).replace(/\s+/g, ' ').trim();
      var detailText = getCleanText(detailNode).replace(/\s+/g, ' ').trim();
      var parsedTail = parseLocationAndTeacher(detailText);
      var weeks = parseWeeks(detailText);

      if (!name) {
        return null;
      }

      return {
        name: name,
        location: parsedTail.location || '',
        teacher: parsedTail.teacher || '',
        weekday: weekday,
        weeks: weeks,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
        colorValue: pickColor(name),
      };
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
            CourseDataChannel.postMessage("DEBUG: 已在 iframe 中定位到课表。");
            break;
          }
        } catch (iframeError) {
          console.error('iframe access error', iframeError);
        }
      }
    }

    if (!tables || tables.length === 0) {
      CourseDataChannel.postMessage("DEBUG: 主页面与 iframe 中均未找到 table.Wjkc / table.courseTable。当前网址: " + window.location.href);
      return;
    }

    CourseDataChannel.postMessage("DEBUG: 已找到课表，开始解析...");

    var courses = [];
    var seen = {};

    tables.forEach(function(table) {
      try {
        if (!table) {
          return;
        }

        table.querySelectorAll('tbody tr').forEach(function(row) {
          try {
            if (!row) {
              return;
            }

            var periodCell = row.querySelector('td.dayPartUnit');
            var periodText = getCleanText(periodCell);
            var rowStartPeriod = Number((periodText.match(/\d{1,2}/) || [])[0]);

            if (!Number.isFinite(rowStartPeriod) || rowStartPeriod < 1 || rowStartPeriod > 13) {
              return;
            }

            row.querySelectorAll('td.td-content').forEach(function(cell) {
              try {
                if (!cell) {
                  return;
                }

                var styleText = String(cell.getAttribute('style') || '').toLowerCase();
                if (styleText.indexOf('display: none') !== -1) {
                  return;
                }

                var weekdayMatch = String(cell.className || '').match(/\btd-content\s+(\d)\b/);
                var weekday = weekdayMatch ? Number(weekdayMatch[1]) : null;
                if (!weekday || weekday < 1 || weekday > 7) {
                  return;
                }

                var rowspan = Number(cell.getAttribute('rowspan') || '1');
                var startPeriod = rowStartPeriod;
                var endPeriod = Math.min(rowStartPeriod + Math.max(rowspan, 1) - 1, 13);

                var tdHtml = Array.from(cell.querySelectorAll(':scope > .tdHtml')).find(function(node) {
                  var nodeStyle = String((node && node.getAttribute('style')) || '').toLowerCase();
                  return node &&
                    getCleanText(node) &&
                    nodeStyle.indexOf('opacity: 0') === -1;
                }) || Array.from(cell.querySelectorAll(':scope > .tdHtml')).find(function(node) {
                  return node && getCleanText(node);
                });

                if (!tdHtml) {
                  return;
                }

                var blocks = splitCourseBlocks(tdHtml);
                blocks.forEach(function(blockNodes) {
                  try {
                    var course = parseBlock(blockNodes, weekday, startPeriod, endPeriod);
                    if (!course) {
                      return;
                    }

                    var key = JSON.stringify(course);
                    if (!seen[key]) {
                      seen[key] = true;
                      courses.push(course);
                    }
                  } catch (blockError) {
                    console.error('parse block error', blockError);
                  }
                });
              } catch (cellError) {
                console.error('parse cell error', cellError);
              }
            });
          } catch (rowError) {
            console.error('parse row error', rowError);
          }
        });
      } catch (tableError) {
        console.error('parse table error', tableError);
      }
    });

    CourseDataChannel.postMessage(JSON.stringify(courses));
  } catch (err) {
    CourseDataChannel.postMessage("ERROR: " + ((err && err.message) ? err.message : String(err)));
  }
})();
''';

class ImportCoursePage extends StatefulWidget {
  const ImportCoursePage({super.key});

  @override
  State<ImportCoursePage> createState() => _ImportCoursePageState();
}

class _ImportCoursePageState extends State<ImportCoursePage> {
  late final WebViewController _controller;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('ImportCoursePage onPageStarted: $url');
          },
          onPageFinished: (url) {
            debugPrint('ImportCoursePage onPageFinished: $url');
          },
          onNavigationRequest: (request) {
            debugPrint('ImportCoursePage onNavigationRequest: ${request.url}');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint(
              'ImportCoursePage onWebResourceError: '
              '${error.errorCode} ${error.description}',
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'CourseDataChannel',
        onMessageReceived: (message) async {
          debugPrint('收到注入回传数据: ${message.message}');
          await _handleImportedMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(academicLoginUrl));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(provider.t('academic_import')),
      ),
      body: WebViewWidget(controller: _controller),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _runExtractScript,
        icon: const Icon(Icons.download_for_offline_outlined),
        label: Text(
          _isImporting ? provider.t('extracting') : provider.t('extract_timetable'),
        ),
      ),
    );
  }

  Future<void> _runExtractScript() async {
    setState(() {
      _isImporting = true;
    });

    try {
      await _controller.runJavaScript(extractScript);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('\u8BFE\u8868\u63D0\u53D6\u5931\u8D25\uFF1A$error'),
        ),
      );
    }
  }

  Future<void> _handleImportedMessage(String rawMessage) async {
    try {
      final provider = context.read<SettingsProvider>();
      if (rawMessage.startsWith('DEBUG:') || rawMessage.startsWith('ERROR:')) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isImporting = false;
        });

        final isError = rawMessage.startsWith('ERROR:');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isError ? Colors.red : Colors.blueGrey,
            content: Text(rawMessage),
          ),
        );
        return;
      }

      final decoded = jsonDecode(rawMessage);
      if (decoded is! List) {
        throw const FormatException(
          '\u8FD4\u56DE\u7684\u6570\u636E\u4E0D\u662F\u8BFE\u7A0B\u6570\u7EC4\u3002',
        );
      }

      final importedCourses = decoded
          .map(
            (item) => Course.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      await context.read<CourseProvider>().addCourses(importedCourses);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.t('import_success')}: ${importedCourses.length}'),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('\u5BFC\u5165\u5931\u8D25\uFF1A$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}
