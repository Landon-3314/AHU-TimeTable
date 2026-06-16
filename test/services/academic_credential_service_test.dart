import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/academic_credential.dart';
import 'package:AnKe/services/academic_credential_service.dart';

void main() {
  test('saves loads overwrites and clears academic credentials', () async {
    final store = _MemoryCredentialStore();
    final service = AcademicCredentialService(store: store);

    expect(await service.load(), isNull);

    await service.save(
      const AcademicCredential(
        studentId: 'G12345678',
        password: 'first-password',
        autoLoginEnabled: true,
      ),
    );

    expect(
      await service.load(),
      const AcademicCredential(
        studentId: 'G12345678',
        password: 'first-password',
        autoLoginEnabled: true,
      ),
    );

    await service.save(
      const AcademicCredential(
        studentId: 'G87654321',
        password: 'second-password',
        autoLoginEnabled: false,
      ),
    );

    expect(
      await service.load(),
      const AcademicCredential(
        studentId: 'G87654321',
        password: 'second-password',
        autoLoginEnabled: false,
      ),
    );

    await service.clear();

    expect(await service.load(), isNull);
    expect(store.values, isEmpty);
  });

  test('returns null when either student id or password is missing', () async {
    final missingPasswordStore = _MemoryCredentialStore()
      ..values[AcademicCredentialService.studentIdKey] = 'G12345678'
      ..values[AcademicCredentialService.autoLoginEnabledKey] = 'true';
    final missingStudentStore = _MemoryCredentialStore()
      ..values[AcademicCredentialService.passwordKey] = 'secret'
      ..values[AcademicCredentialService.autoLoginEnabledKey] = 'true';

    expect(
      await AcademicCredentialService(store: missingPasswordStore).load(),
      isNull,
    );
    expect(
      await AcademicCredentialService(store: missingStudentStore).load(),
      isNull,
    );
  });
}

class _MemoryCredentialStore implements AcademicCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
