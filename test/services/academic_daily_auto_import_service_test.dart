import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/academic_credential.dart';
import 'package:AnKe/services/academic_credential_service.dart';
import 'package:AnKe/services/academic_daily_auto_import_service.dart';

void main() {
  test('daily auto import is not due without saved credentials', () async {
    final service = _createService();

    expect(
      await service.shouldRunDailyTimetableImport(now: DateTime(2026, 6, 4, 8)),
      isFalse,
    );
  });

  test('daily auto import is not due when auto login is disabled', () async {
    final credentialStore = _MemoryCredentialStore();
    await AcademicCredentialService(store: credentialStore).save(
      const AcademicCredential(
        studentId: 'G12345678',
        password: 'secret',
        autoLoginEnabled: false,
      ),
    );
    final service = _createService(credentialStore: credentialStore);

    expect(
      await service.shouldRunDailyTimetableImport(now: DateTime(2026, 6, 4, 8)),
      isFalse,
    );
  });

  test(
    'daily auto import is due once per local day with credentials',
    () async {
      final credentialStore = _MemoryCredentialStore();
      final dailyStore = _MemoryDailyAutoImportStore();
      await AcademicCredentialService(store: credentialStore).save(
        const AcademicCredential(
          studentId: 'G12345678',
          password: 'secret',
          autoLoginEnabled: true,
        ),
      );
      final service = _createService(
        credentialStore: credentialStore,
        dailyStore: dailyStore,
      );

      expect(
        await service.shouldRunDailyTimetableImport(
          now: DateTime(2026, 6, 4, 0, 1),
        ),
        isTrue,
      );

      await service.markDailyTimetableImportCompleted(
        now: DateTime(2026, 6, 4, 0, 1),
      );

      expect(
        await service.shouldRunDailyTimetableImport(
          now: DateTime(2026, 6, 4, 23, 59),
        ),
        isFalse,
      );
      expect(
        await service.shouldRunDailyTimetableImport(now: DateTime(2026, 6, 5)),
        isTrue,
      );
    },
  );
}

AcademicDailyAutoImportService _createService({
  _MemoryCredentialStore? credentialStore,
  _MemoryDailyAutoImportStore? dailyStore,
}) {
  return AcademicDailyAutoImportService(
    credentialService: AcademicCredentialService(
      store: credentialStore ?? _MemoryCredentialStore(),
    ),
    store: dailyStore ?? _MemoryDailyAutoImportStore(),
  );
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

class _MemoryDailyAutoImportStore implements AcademicDailyAutoImportStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
