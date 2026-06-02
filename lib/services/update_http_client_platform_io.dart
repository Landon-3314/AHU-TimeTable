import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createPlatformUpdateClient() {
  if (defaultTargetPlatform == TargetPlatform.android) {
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

http.Client _createIoClient() {
  return IOClient(
    HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = 'TimetableUpdater',
  );
}
