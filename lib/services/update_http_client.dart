import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

typedef UpdateHttpClientFactory = UpdateHttpClient Function();

abstract class UpdateHttpClient {
  Future<UpdateHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  });

  void close();
}

class UpdateHttpResponse {
  const UpdateHttpResponse({
    required this.statusCode,
    required this.contentLength,
    required this.bytes,
    required this.uri,
  });

  final int statusCode;
  final int? contentLength;
  final Stream<List<int>> bytes;
  final Uri uri;
}

UpdateHttpClient createDefaultUpdateHttpClient() {
  return PackageUpdateHttpClient();
}

class PackageUpdateHttpClient implements UpdateHttpClient {
  PackageUpdateHttpClient({http.Client? client})
    : _client = client ?? _createPlatformClient();

  final http.Client _client;

  @override
  Future<UpdateHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', uri);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final response = await _client.send(request);
    return UpdateHttpResponse(
      statusCode: response.statusCode,
      contentLength: response.contentLength,
      bytes: response.stream,
      uri: response.request?.url ?? uri,
    );
  }

  @override
  void close() {
    _client.close();
  }

  static http.Client _createPlatformClient() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final engine = CronetEngine.build(
          cacheMode: CacheMode.memory,
          cacheMaxSize: 2 * 1024 * 1024,
          userAgent: 'TimetableUpdater',
        );
        return CronetClient.fromCronetEngine(engine, closeEngine: true);
      } catch (_) {
        return _createIoClient();
      }
    }
    return _createIoClient();
  }

  static http.Client _createIoClient() {
    return IOClient(
      HttpClient()
        ..connectionTimeout = const Duration(seconds: 20)
        ..userAgent = 'TimetableUpdater',
    );
  }
}
