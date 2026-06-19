import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'academic_api_endpoints.dart';

enum AcademicFetchErrorCode {
  invalidUrl,
  blockedHost,
  channelUnavailable,
  timeout,
  network,
  httpStatus,
  loginExpired,
  malformedResponse,
}

class AcademicFetchException implements Exception {
  AcademicFetchException(this.code, this.message, {this.status, this.url});

  final AcademicFetchErrorCode code;
  final String message;
  final int? status;
  final String? url;

  @override
  String toString() => message;
}

class AcademicFetchResponse {
  const AcademicFetchResponse({
    required this.requestId,
    required this.ok,
    required this.status,
    required this.redirected,
    required this.url,
    required this.contentType,
    required this.body,
  });

  final String requestId;
  final bool ok;
  final int status;
  final bool redirected;
  final String url;
  final String contentType;
  final String body;

  bool get isLoginExpired {
    final parsed = Uri.tryParse(url);
    final host = parsed?.host.toLowerCase() ?? '';
    final path = parsed?.path.toLowerCase() ?? '';
    final lowerBody = body.toLowerCase();
    return host == AcademicApiEndpoints.casHost ||
        path.contains('/student/login') ||
        lowerBody.contains('id="casloginform"') ||
        lowerBody.contains("id='casloginform'") ||
        lowerBody.contains('统一身份认证');
  }

  factory AcademicFetchResponse.fromJson(Map<String, dynamic> json) {
    return AcademicFetchResponse(
      requestId: _string(json['requestId']),
      ok: json['ok'] == true,
      status: _int(json['status']),
      redirected: json['redirected'] == true,
      url: _string(json['url']),
      contentType: _string(json['contentType']),
      body: _string(json['body']),
    );
  }
}

class AcademicWebViewFetchClient {
  AcademicWebViewFetchClient({
    required WebViewController controller,
    this.timeout = const Duration(seconds: 20),
  }) : _controller = controller;

  static const String channelName = 'AcademicFetchBridge';

  final WebViewController _controller;
  final Duration timeout;
  final Map<String, _PendingFetch> _pending = <String, _PendingFetch>{};
  int _nextRequestId = 0;

  Future<AcademicFetchResponse> fetch(
    Uri uri, {
    String accept = 'application/json,text/html,*/*',
    Duration? timeout,
  }) async {
    _validateAllowedUri(uri);
    final requestId =
        'academic-fetch-${DateTime.now().microsecondsSinceEpoch}-${_nextRequestId++}';
    final completer = Completer<AcademicFetchResponse>();
    final effectiveTimeout = timeout ?? this.timeout;
    final timer = Timer(effectiveTimeout, () {
      final pending = _pending.remove(requestId);
      if (pending == null || pending.completer.isCompleted) {
        return;
      }
      pending.completer.completeError(
        AcademicFetchException(
          AcademicFetchErrorCode.timeout,
          '教务接口请求超时，请确认登录状态和网络。',
          url: uri.toString(),
        ),
      );
    });
    _pending[requestId] = _PendingFetch(completer: completer, timer: timer);

    try {
      await _controller.runJavaScript(
        _buildFetchScript(requestId, uri, accept),
      );
    } catch (error) {
      _completeError(
        requestId,
        AcademicFetchException(
          AcademicFetchErrorCode.channelUnavailable,
          '教务 WebView 通道不可用: $error',
          url: uri.toString(),
        ),
      );
    }

    final response = await completer.future;
    if (response.isLoginExpired) {
      throw AcademicFetchException(
        AcademicFetchErrorCode.loginExpired,
        '教务登录已失效，请重新登录后再导入。',
        status: response.status,
        url: response.url,
      );
    }
    if (!response.ok || response.status >= 400) {
      throw AcademicFetchException(
        AcademicFetchErrorCode.httpStatus,
        '教务接口请求失败（HTTP ${response.status}）。',
        status: response.status,
        url: response.url,
      );
    }
    return response;
  }

  void handleMessage(String rawMessage) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        throw const FormatException('bridge message is not an object');
      }
      json = Map<String, dynamic>.from(decoded);
    } catch (error) {
      return;
    }

    final requestId = _string(json['requestId']);
    final pending = _pending.remove(requestId);
    if (pending == null || pending.completer.isCompleted) {
      return;
    }
    pending.timer.cancel();
    if (json['error'] != null) {
      pending.completer.completeError(
        AcademicFetchException(
          AcademicFetchErrorCode.network,
          _string(json['error']),
          status: _int(json['status']),
          url: _string(json['url']),
        ),
      );
      return;
    }
    try {
      pending.completer.complete(AcademicFetchResponse.fromJson(json));
    } catch (error) {
      pending.completer.completeError(
        AcademicFetchException(
          AcademicFetchErrorCode.malformedResponse,
          '教务接口响应结构异常: $error',
        ),
      );
    }
  }

  void dispose() {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          AcademicFetchException(
            AcademicFetchErrorCode.channelUnavailable,
            '教务 WebView 通道已释放。',
          ),
        );
      }
    }
    _pending.clear();
  }

  String _buildFetchScript(String requestId, Uri uri, String accept) {
    final requestIdJson = jsonEncode(requestId);
    final urlJson = jsonEncode(uri.toString());
    final acceptJson = jsonEncode(accept);
    return '''
(function() {
  const requestId = $requestIdJson;
  const targetUrlText = $urlJson;
  const acceptHeader = $acceptJson;
  const post = function(payload) {
    if (window.$channelName && window.$channelName.postMessage) {
      window.$channelName.postMessage(JSON.stringify(payload));
    }
  };
  (async function() {
    try {
      const target = new URL(targetUrlText, window.location.href);
      if (target.protocol !== 'https:' || target.host !== '${AcademicApiEndpoints.academicHost}') {
        throw new Error('BLOCKED_HOST');
      }
      if (window.location.host !== target.host) {
        throw new Error('NOT_SAME_ORIGIN');
      }
      const response = await fetch(target.toString(), {
        credentials: 'include',
        headers: { 'Accept': acceptHeader }
      });
      const body = await response.text();
      post({
        requestId,
        ok: response.ok,
        status: response.status,
        redirected: response.redirected,
        url: response.url,
        contentType: response.headers.get('content-type') || '',
        body
      });
    } catch (error) {
      post({
        requestId,
        ok: false,
        status: 0,
        redirected: false,
        url: targetUrlText,
        contentType: '',
        body: '',
        error: error && error.message ? error.message : String(error)
      });
    }
  })();
})();
''';
  }

  void _completeError(String requestId, Object error) {
    final pending = _pending.remove(requestId);
    if (pending == null || pending.completer.isCompleted) {
      return;
    }
    pending.timer.cancel();
    pending.completer.completeError(error);
  }

  void _validateAllowedUri(Uri uri) {
    if (!uri.hasScheme || uri.scheme != 'https') {
      throw AcademicFetchException(
        AcademicFetchErrorCode.invalidUrl,
        '只允许请求 HTTPS 教务接口。',
        url: uri.toString(),
      );
    }
    if (uri.host != AcademicApiEndpoints.academicHost) {
      throw AcademicFetchException(
        AcademicFetchErrorCode.blockedHost,
        '只允许请求教务同源接口。',
        url: uri.toString(),
      );
    }
  }
}

class _PendingFetch {
  const _PendingFetch({required this.completer, required this.timer});

  final Completer<AcademicFetchResponse> completer;
  final Timer timer;
}

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? 0;
}
