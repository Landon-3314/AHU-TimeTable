import 'dart:async';

import 'package:http/http.dart' as http;

import 'update_http_client_platform.dart'
    if (dart.library.io) 'update_http_client_platform_io.dart'
    as platform;

typedef UpdateHttpClientFactory = UpdateHttpClient Function();

abstract class UpdateHttpClient {
  Future<UpdateHttpResponse> get(Uri uri, {Map<String, String>? headers});

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
    : _client = client ?? platform.createPlatformUpdateClient();

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
}
