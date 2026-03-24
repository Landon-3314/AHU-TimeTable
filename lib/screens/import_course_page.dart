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
    CourseDataChannel.postMessage("DEBUG: Script started...");

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

    function normalizeDetailText(value) {
      return String(value || '')
        .replace(/\u00a0/g, ' ')
        .replace(/[\uFF0C\u3001]/g, ',')
        .replace(/[~\uFF5E]/g, '-')
        .replace(/[?？]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }

    function htmlToPlainText(html) {
      return String(html || '')
        .replace(/&nbsp;/gi, ' ')
        .replace(/<\/div>/gi, '\n')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]*>/g, ' ')
        .replace(/\u00a0/g, ' ')
        .replace(/[ \t]+/g, ' ')
        .replace(/\n\s+\n/g, '\n')
        .replace(/\n{2,}/g, '\n')
        .trim();
    }

    function hasWeekToken(text) {
      // Support both normal "周" and mojibake variant like "鍛".
      return /[\u5468\u935b]/.test(String(text || ''));
    }

    function hasPeriodToken(text) {
      // Support both normal "节" and mojibake variant like "鑺".
      return /[\u8282\u947a]/.test(String(text || ''));
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
        return [];
      }

      var result = [];
      for (var i = from; i <= to; i += 1) {
        result.push(i);
      }
      return result;
    }

    function extractWeekSpec(detailText) {
      var text = normalizeDetailText(detailText);
      return text.match(/\(([\d\s,\-]+)\s*[\u5468\u935b](?:\(([\u5355\u53cc])\))?\)/);
    }

    function parseWeeksFromParts(rawBody, oddEven) {
      rawBody = String(rawBody || '').trim();
      oddEven = String(oddEven || '').trim();
      if (!rawBody) {
        return [1];
      }

      var seenWeeks = {};
      var weeks = [];

      rawBody.split(',').forEach(function(part) {
        var segment = String(part || '').trim();
        if (!segment) {
          return;
        }

        var rangeMatch = segment.match(/^(\d{1,2})\s*[-~]\s*(\d{1,2})$/);
        if (rangeMatch) {
          expandWeeks(rangeMatch[1], rangeMatch[2]).forEach(function(week) {
            if (!seenWeeks[week]) {
              seenWeeks[week] = true;
              weeks.push(week);
            }
          });
          return;
        }

        var singleMatch = segment.match(/^(\d{1,2})$/);
        if (singleMatch) {
          var week = Number(singleMatch[1]);
          if (!seenWeeks[week]) {
            seenWeeks[week] = true;
            weeks.push(week);
          }
        }
      });

      weeks.sort(function(a, b) {
        return a - b;
      });

      if (oddEven === '\u5355') {
        weeks = weeks.filter(function(week) {
          return week % 2 === 1;
        });
      } else if (oddEven === '\u53cc') {
        weeks = weeks.filter(function(week) {
          return week % 2 === 0;
        });
      }

      return weeks.length > 0 ? weeks : [1];
    }

    function parseWeeksRangeText(weeksText) {
      return parseWeeksFromParts(
        String(weeksText || '')
          .replace(/[~\uFF5E]/g, '-')
          .replace(/\s+/g, ''),
        '',
      );
    }

    function parsePeriodRange(periodText, fallbackStart, fallbackEnd) {
      var text = String(periodText || '').trim();
      if (!text) {
        return {
          startPeriod: fallbackStart,
          endPeriod: fallbackEnd,
        };
      }

      var rangeMatch = text.match(/^(\d{1,2})\s*[-~]\s*(\d{1,2})$/);
      if (rangeMatch) {
        return {
          startPeriod: Number(rangeMatch[1]),
          endPeriod: Number(rangeMatch[2]),
        };
      }

      var singleMatch = text.match(/^(\d{1,2})$/);
      if (singleMatch) {
        var p = Number(singleMatch[1]);
        return {
          startPeriod: p,
          endPeriod: p,
        };
      }

      return {
        startPeriod: fallbackStart,
        endPeriod: fallbackEnd,
      };
    }

    function extractCoursesFromTdHtml(tdHtml, weekday, fallbackStart, fallbackEnd) {
      if (!tdHtml) {
        return [];
      }

      var nameNode = tdHtml.querySelector('.course-name');
      var name = getCleanText(nameNode).replace(/\s+/g, ' ').trim();
      if (!name) {
        return [];
      }

      var plainText = htmlToPlainText(tdHtml.innerHTML || '');
      if (!plainText) {
        return [];
      }

      // Global extraction for mixed div + bare text-node structures.
      // Supports:
      // (1-3,5~18周) (3-5节) 校区 地点 老师
      // and mojibake variants of 周/节.
      var regex = /\(([\d,\-~]+)\s*[\u5468\u935b]\)\s*\(([\d\-~]+)\s*[\u8282\u947a]\)\s+(\S+)\s+(\S+)\s+([\u4e00-\u9fa5a-zA-Z\/·]+)/g;
      var matches = [];
      var m;
      while ((m = regex.exec(plainText)) !== null) {
        matches.push(m);
      }
      if (matches.length === 0) {
        return [];
      }

      var results = [];
      var seen = {};
      matches.forEach(function(match) {
        var weeks = parseWeeksRangeText(match[1]);
        var parsedPeriod = parsePeriodRange(match[2], fallbackStart, fallbackEnd);
        var location = String((match[3] || '') + ' ' + (match[4] || ''))
          .replace(/\s+/g, ' ')
          .trim();
        var teacher = String(match[5] || '').trim();

        var course = {
          name: name,
          location: location,
          teacher: teacher,
          weekday: weekday,
          weeks: weeks,
          startPeriod: parsedPeriod.startPeriod,
          endPeriod: parsedPeriod.endPeriod,
          colorValue: pickColor(name),
        };

        var key = JSON.stringify(course);
        if (!seen[key]) {
          seen[key] = true;
          results.push(course);
        }
      });

      return results;
    }

    function parseWeeks(detailText) {
      var match = extractWeekSpec(detailText);
      if (!match) {
        // Fallback for malformed course structures where week marker may
        // not be wrapped by complete parentheses.
        var looseMatch = normalizeDetailText(detailText).match(
          /(?:\()?\s*([\d\s,\-]+)\s*[\u5468\u935b](?:\(([\u5355\u53cc])\))?(?:\))?/
        );
        if (!looseMatch) {
          return [1];
        }
        return parseWeeksFromParts(looseMatch[1], looseMatch[2]);
      }
      return parseWeeksFromParts(match[1], match[2]);
    }

    function extractWeekMarkers(detailText) {
      var text = normalizeDetailText(detailText);
      var markers = [];
      var regex = /(?:\()?\s*([\d\s,\-]+)\s*[\u5468\u935b](?:\(([\u5355\u53cc])\))?(?:\))?/g;
      var match;
      while ((match = regex.exec(text)) !== null) {
        markers.push({
          index: match.index,
          rawBody: String(match[1] || '').trim(),
          oddEven: String(match[2] || '').trim(),
        });
      }
      return markers;
    }

    function splitDetailSegments(detailText) {
      var text = normalizeDetailText(detailText);
      if (!text) {
        return [];
      }

      var markers = extractWeekMarkers(text);
      if (markers.length <= 1) {
        return [text];
      }

      var segments = [];
      for (var i = 0; i < markers.length; i += 1) {
        var start = markers[i].index;
        var end = i + 1 < markers.length ? markers[i + 1].index : text.length;
        var segment = String(text.slice(start, end) || '').trim();
        if (segment) {
          segments.push(segment);
        }
      }
      return segments.length > 0 ? segments : [text];
    }

    function stripTimingFragments(detailText) {
      return normalizeDetailText(detailText)
        .replace(/\(([\d\s,\-]+)\s*[\u5468\u935b](?:\((?:[\u5355\u53cc])\))?\)/g, ' ')
        .replace(/\(\d{1,2}\s*-\s*\d{1,2}\s*[\u8282\u947a]\)/g, ' ')
        .replace(/\(\d{1,2}\s*[\u8282\u947a]\)/g, ' ')
        .replace(/[()]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }

    function parseLocationAndTeacher(detailText) {
      var text = stripTimingFragments(detailText);
      if (!text) {
        return {
          location: '',
          teacher: '',
        };
      }

      var tokens = text.split(/\s+/).filter(function(token) {
        return !!token;
      });

      if (tokens.length === 0) {
        return {
          location: '',
          teacher: '',
        };
      }

      if (tokens.length === 1) {
        return {
          location: tokens[0],
          teacher: '',
        };
      }

      var tailMatch = text.match(/(.+?)\s+([^\s()]+(?:\/[^\s()]+)*)$/);
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

    function isDetailNode(node) {
      if (!node) {
        return false;
      }

      if (node.classList && (
        node.classList.contains('course-name') ||
        node.classList.contains('lesson-name')
      )) {
        return false;
      }

      var text = normalizeDetailText(getCleanText(node));
      return hasWeekToken(text) && hasPeriodToken(text);
    }

    function parseBlock(blockNodes, weekday, startPeriod, endPeriod) {
      var nameNode = blockNodes.find(function(node) {
        return node && node.classList && node.classList.contains('course-name');
      });

      var detailNodes = blockNodes.filter(function(node) {
        return isDetailNode(node);
      });

      var name = getCleanText(nameNode).replace(/\s+/g, ' ').trim();

      if (!name) {
        return [];
      }

      var detailText = '';
      if (detailNodes.length > 0) {
        detailText = normalizeDetailText(
          detailNodes.map(function(node) {
            return getCleanText(node);
          }).join('\n')
        );
      }

      if (!detailText) {
        var fallbackText = normalizeDetailText(
          blockNodes
            .filter(function(node) {
              return node &&
                (!node.classList || !node.classList.contains('course-name')) &&
                (!node.classList || !node.classList.contains('lesson-name'));
            })
            .map(function(node) {
              return getCleanText(node);
            })
            .join('\n')
        );
        detailText = fallbackText;
      }

      if (!detailText) {
        detailText = normalizeDetailText(
          blockNodes.map(function(node) {
            return getCleanText(node);
          }).join('\n')
        );
      }

      if (!hasWeekToken(detailText)) {
        var wholeText = normalizeDetailText(
          blockNodes.map(function(node) {
            return getCleanText(node);
          }).join(' ')
        );
        if (hasWeekToken(wholeText)) {
          detailText = wholeText;
        }
      }

      var detailSegments = splitDetailSegments(detailText);
      var results = [];
      var seenInBlock = {};

      detailSegments.forEach(function(segment) {
        var parsedTail = parseLocationAndTeacher(segment);
        var weeks = parseWeeks(segment);
        var course = {
          name: name,
          location: parsedTail.location || '',
          teacher: parsedTail.teacher || '',
          weekday: weekday,
          weeks: weeks,
          startPeriod: startPeriod,
          endPeriod: endPeriod,
          colorValue: pickColor(name),
        };

        var key = JSON.stringify(course);
        if (!seenInBlock[key]) {
          seenInBlock[key] = true;
          results.push(course);
        }
      });

      if (results.length === 0) {
        results.push({
          name: name,
          location: '',
          teacher: '',
          weekday: weekday,
          weeks: [1],
          startPeriod: startPeriod,
          endPeriod: endPeriod,
          colorValue: pickColor(name),
        });
      }

      return results;
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
            CourseDataChannel.postMessage("DEBUG: Found timetable inside iframe.");
            break;
          }
        } catch (iframeError) {
          console.error('iframe access error', iframeError);
        }
      }
    }

    if (!tables || tables.length === 0) {
      CourseDataChannel.postMessage(
        "DEBUG: No timetable table found in main document or iframe. URL: " + window.location.href
      );
      return;
    }

    CourseDataChannel.postMessage("DEBUG: Timetable found, parsing...");

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

                var globalParsedCourses = extractCoursesFromTdHtml(
                  tdHtml,
                  weekday,
                  startPeriod,
                  endPeriod,
                );
                if (globalParsedCourses.length > 0) {
                  globalParsedCourses.forEach(function(course) {
                    var key = JSON.stringify(course);
                    if (!seen[key]) {
                      seen[key] = true;
                      courses.push(course);
                    }
                  });
                  return;
                }

                var blocks = splitCourseBlocks(tdHtml);
                blocks.forEach(function(blockNodes) {
                  try {
                    var parsedCourses = parseBlock(blockNodes, weekday, startPeriod, endPeriod);
                    parsedCourses.forEach(function(course) {
                      var key = JSON.stringify(course);
                      if (!seen[key]) {
                        seen[key] = true;
                        courses.push(course);
                      }
                    });
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
          debugPrint('ImportCoursePage message: ${message.message}');
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
      if (rawMessage.startsWith('DEBUG:')) {
        // Keep parser diagnostics in logs only; never surface DEBUG via SnackBar.
        debugPrint('ImportCoursePage DEBUG: $rawMessage');
        return;
      }

      if (rawMessage.startsWith('ERROR:')) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isImporting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
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

      Navigator.of(context).pop(importedCourses.length);
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
