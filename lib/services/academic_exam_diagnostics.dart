class AcademicExamDiagnostics {
  const AcademicExamDiagnostics._();

  static const String installNetworkProbeScript = r'''
(function() {
  try {
    const root = window;
    if (root.__ankeAcademicExamProbe &&
        root.__ankeAcademicExamProbe.installed) {
      return 'ALREADY_INSTALLED';
    }

    const probe = root.__ankeAcademicExamProbe || { requests: [] };
    probe.requests = probe.requests || [];
    probe.installed = true;
    probe.originalFetch = root.fetch;
    probe.originalXHROpen = XMLHttpRequest.prototype.open;
    probe.originalXHRSend = XMLHttpRequest.prototype.send;

    function textOf(value) {
      try {
        return value == null ? '' : String(value);
      } catch (_) {
        return '';
      }
    }

    function trim(text, limit) {
      const value = textOf(text).replace(/\s+/g, ' ').trim();
      return value.length > limit ? value.slice(0, limit) + '...' : value;
    }

    function record(entry) {
      try {
        probe.requests.push(entry);
        if (probe.requests.length > 80) {
          probe.requests.splice(0, probe.requests.length - 80);
        }
      } catch (_) {}
    }

    if (typeof root.fetch === 'function') {
      root.fetch = function(input, init) {
        const startedAt = Date.now();
        const method = textOf(
          init && init.method ? init.method : input && input.method
        ) || 'GET';
        const url = textOf(input && input.url ? input.url : input);
        return probe.originalFetch.apply(this, arguments).then(
          function(response) {
            const responseUrl = textOf(response.url || url);
            const status = response.status || 0;
            const contentType = response.headers && response.headers.get
              ? textOf(response.headers.get('content-type'))
              : '';
            try {
              response.clone().text().then(
                function(body) {
                  record({
                    type: 'fetch',
                    method: method.toUpperCase(),
                    url: responseUrl,
                    status: status,
                    ok: response.ok === true,
                    contentType: contentType,
                    bodyLength: textOf(body).length,
                    durationMs: Date.now() - startedAt,
                    snippet: trim(body, 300)
                  });
                },
                function(error) {
                  record({
                    type: 'fetch',
                    method: method.toUpperCase(),
                    url: responseUrl,
                    status: status,
                    ok: response.ok === true,
                    contentType: contentType,
                    bodyLength: 0,
                    durationMs: Date.now() - startedAt,
                    error: textOf(error && error.message ? error.message : error)
                  });
                }
              );
            } catch (error) {
              record({
                type: 'fetch',
                method: method.toUpperCase(),
                url: responseUrl,
                status: status,
                ok: response.ok === true,
                contentType: contentType,
                bodyLength: 0,
                durationMs: Date.now() - startedAt,
                error: textOf(error && error.message ? error.message : error)
              });
            }
            return response;
          },
          function(error) {
            record({
              type: 'fetch',
              method: method.toUpperCase(),
              url: url,
              status: 0,
              ok: false,
              contentType: '',
              bodyLength: 0,
              durationMs: Date.now() - startedAt,
              error: textOf(error && error.message ? error.message : error)
            });
            throw error;
          }
        );
      };
    }

    XMLHttpRequest.prototype.open = function(method, url) {
      this.__ankeAcademicExamProbeMeta = {
        method: textOf(method || 'GET').toUpperCase(),
        url: textOf(url),
        startedAt: 0
      };
      return probe.originalXHROpen.apply(this, arguments);
    };

    XMLHttpRequest.prototype.send = function() {
      const xhr = this;
      const meta = xhr.__ankeAcademicExamProbeMeta || {
        method: 'GET',
        url: '',
        startedAt: 0
      };
      meta.startedAt = Date.now();
      try {
        xhr.addEventListener('loadend', function() {
          let body = '';
          try {
            if (!xhr.responseType || xhr.responseType === 'text') {
              body = textOf(xhr.responseText);
            }
          } catch (_) {
            body = '';
          }
          let contentType = '';
          try {
            contentType = textOf(xhr.getResponseHeader('content-type'));
          } catch (_) {
            contentType = '';
          }
          record({
            type: 'xhr',
            method: meta.method || 'GET',
            url: textOf(xhr.responseURL || meta.url),
            status: xhr.status || 0,
            ok: xhr.status >= 200 && xhr.status < 400,
            contentType: contentType,
            bodyLength: body.length,
            durationMs: Date.now() - meta.startedAt,
            snippet: trim(body, 300)
          });
        });
      } catch (_) {}
      return probe.originalXHRSend.apply(this, arguments);
    };

    root.__ankeAcademicExamProbe = probe;
    return 'INSTALLED';
  } catch (error) {
    return 'JS_ERROR: ' +
      (error && error.message ? error.message : String(error));
  }
})();
''';

  static const String collectSnapshotScript = r'''
(function() {
  try {
    const keywordPattern =
      /(exam|student|arrange|vm|info|考试|考场|座位|刷新)/i;
    const errors = [];

    function textOf(value) {
      try {
        return value == null ? '' : String(value);
      } catch (_) {
        return '';
      }
    }

    function compact(text, limit) {
      const value = textOf(text).replace(/\s+/g, ' ').trim();
      return value.length > limit ? value.slice(0, limit) + '...' : value;
    }

    function listScriptSrcs(doc) {
      try {
        return Array.from(doc.scripts || [])
          .map(function(script) { return script.src || ''; })
          .filter(function(src) { return !!src; })
          .slice(-30);
      } catch (error) {
        errors.push('SCRIPT_SRC_ERROR: ' + textOf(error.message || error));
        return [];
      }
    }

    function countInlineScripts(doc) {
      try {
        return Array.from(doc.scripts || [])
          .filter(function(script) { return !script.src; })
          .length;
      } catch (_) {
        return 0;
      }
    }

    function bodyTextLength(doc) {
      try {
        return doc.body
          ? textOf(doc.body.innerText || doc.body.textContent).length
          : 0;
      } catch (_) {
        return 0;
      }
    }

    function documentLength(doc) {
      try {
        return doc.documentElement
          ? textOf(doc.documentElement.outerHTML).length
          : 0;
      } catch (_) {
        return 0;
      }
    }

    function collectWindows(targetWindow, bucket, visited) {
      if (!targetWindow || visited.indexOf(targetWindow) !== -1) {
        return;
      }
      visited.push(targetWindow);
      bucket.push(targetWindow);

      let frameCount = 0;
      try {
        frameCount = targetWindow.frames ? targetWindow.frames.length : 0;
      } catch (error) {
        errors.push('FRAME_COUNT_ERROR: ' + textOf(error.message || error));
        frameCount = 0;
      }
      for (let index = 0; index < frameCount; index += 1) {
        try {
          collectWindows(targetWindow.frames[index], bucket, visited);
        } catch (error) {
          errors.push('FRAME_ACCESS_ERROR: ' + textOf(error.message || error));
        }
      }
    }

    function collectResources() {
      try {
        if (!window.performance || !performance.getEntriesByType) {
          return [];
        }
        const interestingTypes = [
          'fetch',
          'xmlhttprequest',
          'script',
          'iframe',
          'document'
        ];
        return performance.getEntriesByType('resource')
          .filter(function(entry) {
            return interestingTypes.indexOf(entry.initiatorType) !== -1 ||
              keywordPattern.test(entry.name || '');
          })
          .slice(-50)
          .map(function(entry) {
            return {
              name: textOf(entry.name),
              initiatorType: textOf(entry.initiatorType),
              duration: Math.round((entry.duration || 0) * 10) / 10
            };
          });
      } catch (error) {
        errors.push('RESOURCE_ERROR: ' + textOf(error.message || error));
        return [];
      }
    }

    function collectStorageKeys(storage) {
      try {
        const keys = [];
        for (let index = 0; index < storage.length; index += 1) {
          const key = textOf(storage.key(index));
          if (keywordPattern.test(key)) {
            keys.push(key);
          }
        }
        return keys.slice(0, 50);
      } catch (error) {
        errors.push('STORAGE_ERROR: ' + textOf(error.message || error));
        return [];
      }
    }

    function collectWindowKeys() {
      try {
        return Object.keys(window)
          .filter(function(key) { return keywordPattern.test(key); })
          .slice(0, 50);
      } catch (error) {
        errors.push('WINDOW_KEYS_ERROR: ' + textOf(error.message || error));
        return [];
      }
    }

    function collectDomStats(doc) {
      try {
        const nodes = Array.from(doc.querySelectorAll('body *')).slice(0, 2000);
        return {
          examTableCount: doc.querySelectorAll(
            '#exams, table.exam-table, table#exams'
          ).length,
          unfinishedRowCount: doc.querySelectorAll('tr.unfinished').length,
          examTextNodeCount: nodes.filter(function(node) {
            return keywordPattern.test(
              textOf(node.innerText || node.textContent).slice(0, 300)
            );
          }).length,
          studentExamListType: typeof window.studentExamList,
          studentExamListLength: Array.isArray(window.studentExamList)
            ? window.studentExamList.length
            : 0
        };
      } catch (error) {
        errors.push('DOM_ERROR: ' + textOf(error.message || error));
        return {};
      }
    }

    const windows = [];
    collectWindows(window, windows, []);
    const frames = [];
    for (let index = 1; index < windows.length; index += 1) {
      try {
        const frameWindow = windows[index];
        const doc = frameWindow.document;
        frames.push({
          href: textOf(frameWindow.location && frameWindow.location.href),
          title: textOf(doc && doc.title),
          readyState: textOf(doc && doc.readyState),
          bodyTextLength: bodyTextLength(doc),
          documentLength: documentLength(doc),
          scriptSrcs: listScriptSrcs(doc),
          inlineScriptCount: countInlineScripts(doc)
        });
      } catch (error) {
        errors.push('FRAME_SUMMARY_ERROR: ' + textOf(error.message || error));
      }
    }

    const doc = document;
    const probe = window.__ankeAcademicExamProbe || { requests: [] };
    return JSON.stringify({
      href: textOf(window.location && window.location.href),
      title: textOf(doc.title),
      readyState: textOf(doc.readyState),
      documentLength: documentLength(doc),
      bodyTextLength: bodyTextLength(doc),
      scriptSrcs: listScriptSrcs(doc),
      inlineScriptCount: countInlineScripts(doc),
      iframes: frames,
      resources: collectResources(),
      networkRequests: (probe.requests || []).slice(-50),
      windowKeys: collectWindowKeys(),
      storageKeys: {
        local: collectStorageKeys(window.localStorage),
        session: collectStorageKeys(window.sessionStorage)
      },
      dom: collectDomStats(doc),
      errors: errors
    });
  } catch (error) {
    return JSON.stringify({
      href: '',
      title: '',
      readyState: '',
      documentLength: 0,
      bodyTextLength: 0,
      iframes: [],
      resources: [],
      networkRequests: [],
      windowKeys: [],
      storageKeys: { local: [], session: [] },
      dom: {},
      errors: [
        'SNAPSHOT_ERROR: ' +
          (error && error.message ? error.message : String(error))
      ]
    });
  }
})();
''';

  static List<String> summarizeSnapshot(
    Map<String, dynamic> snapshot, {
    String stage = 'snapshot',
    int maxItems = 8,
  }) {
    final frames = _list(snapshot['iframes']);
    final lines = <String>[
      'exam diag $stage page href=${_text(snapshot['href'])} '
          'title=${_text(snapshot['title'])} '
          'ready=${_text(snapshot['readyState'])} '
          'docLength=${_text(snapshot['documentLength'])} '
          'bodyTextLength=${_text(snapshot['bodyTextLength'])} '
          'frames=${frames.length}',
    ];

    final dom = _map(snapshot['dom']);
    if (dom.isNotEmpty) {
      lines.add(
        'exam diag $stage dom '
        'examTables=${_text(dom['examTableCount'])} '
        'unfinishedRows=${_text(dom['unfinishedRowCount'])} '
        'examTextNodes=${_text(dom['examTextNodeCount'])}',
      );
    }

    final scriptSrcs = _list(snapshot['scriptSrcs']);
    if (scriptSrcs.isNotEmpty) {
      lines.add(
        'exam diag $stage scripts ${_joinLimited(scriptSrcs, maxItems)}',
      );
    }

    for (final frame in frames.take(maxItems)) {
      final frameMap = _map(frame);
      lines.add(
        'exam diag $stage frame '
        'href=${_text(frameMap['href'])} '
        'title=${_text(frameMap['title'])} '
        'ready=${_text(frameMap['readyState'])} '
        'bodyTextLength=${_text(frameMap['bodyTextLength'])} '
        'scripts=${_joinLimited(_list(frameMap['scriptSrcs']), maxItems)}',
      );
    }

    for (final request in _list(snapshot['networkRequests']).take(maxItems)) {
      final requestMap = _map(request);
      lines.add(
        'exam diag $stage network '
        '${_text(requestMap['type'])} '
        '${_text(requestMap['method'])} '
        '${_text(requestMap['url'])} '
        'status=${_text(requestMap['status'])} '
        'contentType=${_text(requestMap['contentType'])} '
        'bodyLength=${_text(requestMap['bodyLength'])} '
        'snippet=${_text(requestMap['snippet'])}',
      );
    }

    for (final resource in _list(snapshot['resources']).take(maxItems)) {
      final resourceMap = _map(resource);
      lines.add(
        'exam diag $stage resource '
        '${_text(resourceMap['initiatorType'])} '
        '${_text(resourceMap['name'])} '
        'duration=${_text(resourceMap['duration'])}',
      );
    }

    final storageKeys = _map(snapshot['storageKeys']);
    lines.add(
      'exam diag $stage keys '
      'window=${_joinLimited(_list(snapshot['windowKeys']), maxItems)} '
      'localStorage=${_joinLimited(_list(storageKeys['local']), maxItems)} '
      'sessionStorage=${_joinLimited(_list(storageKeys['session']), maxItems)}',
    );

    for (final error in _list(snapshot['errors']).take(maxItems)) {
      lines.add('exam diag $stage error ${_text(error)}');
    }

    return lines;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<Object?> _list(Object? value) {
    if (value is List) {
      return value;
    }
    return const <Object?>[];
  }

  static String _joinLimited(List<Object?> values, int maxItems) {
    if (values.isEmpty) {
      return '-';
    }
    final items = values.take(maxItems).map(_text).toList();
    if (values.length > maxItems) {
      items.add('...+${values.length - maxItems}');
    }
    return items.join(',');
  }

  static String _text(Object? value) {
    return '${value ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
