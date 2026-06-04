import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/academic_credential.dart';

abstract class AcademicCredentialStore {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);
}

class FlutterSecureCredentialStore implements AcademicCredentialStore {
  const FlutterSecureCredentialStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class AcademicCredentialService {
  const AcademicCredentialService({
    AcademicCredentialStore store = const FlutterSecureCredentialStore(),
  }) : _store = store;

  static const String studentIdKey = 'academic.studentId';
  static const String passwordKey = 'academic.password';
  static const String autoLoginEnabledKey = 'academic.autoLoginEnabled';

  final AcademicCredentialStore _store;

  Future<AcademicCredential?> load() async {
    final studentId = (await _store.read(studentIdKey))?.trim() ?? '';
    final password = await _store.read(passwordKey) ?? '';
    final autoLoginEnabled = (await _store.read(autoLoginEnabledKey)) == 'true';

    if (studentId.isEmpty || password.isEmpty) {
      return null;
    }

    return AcademicCredential(
      studentId: studentId,
      password: password,
      autoLoginEnabled: autoLoginEnabled,
    );
  }

  Future<void> save(AcademicCredential credential) async {
    await _store.write(key: studentIdKey, value: credential.studentId.trim());
    await _store.write(key: passwordKey, value: credential.password);
    await _store.write(
      key: autoLoginEnabledKey,
      value: credential.autoLoginEnabled ? 'true' : 'false',
    );
  }

  Future<void> clear() async {
    await _store.delete(studentIdKey);
    await _store.delete(passwordKey);
    await _store.delete(autoLoginEnabledKey);
  }
}
