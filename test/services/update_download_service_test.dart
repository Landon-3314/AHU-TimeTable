import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/services/update_download_service.dart';

void main() {
  test('validates downloaded APK sha256', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/timetable.apk');
    await file.writeAsString('apk-bytes');

    const expectedHash =
        '1e10ba560383b17472b4cf72fef8f9e76c66815a3e6ae8c5a9b0c5e696b0bdf8';

    expect(
      UpdateDownloadService.verifySha256(file, expectedHash),
      completion(isTrue),
    );
    expect(
      UpdateDownloadService.verifySha256(file, '0' * 64),
      completion(isFalse),
    );
  });

  test('treats blank sha256 as not verifiable instead of valid', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/timetable.apk');
    await file.writeAsString('apk-bytes');

    expect(UpdateDownloadService.verifySha256(file, ''), completion(isFalse));
  });
}
