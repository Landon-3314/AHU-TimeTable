import 'package:shared_preferences/shared_preferences.dart';

import 'academic_credential_service.dart';

abstract class AcademicDailyAutoImportStore {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});
}

class SharedPreferencesAcademicDailyAutoImportStore
    implements AcademicDailyAutoImportStore {
  const SharedPreferencesAcademicDailyAutoImportStore();

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }
}

class AcademicDailyAutoImportService {
  const AcademicDailyAutoImportService({
    this.credentialService = const AcademicCredentialService(),
    this.store = const SharedPreferencesAcademicDailyAutoImportStore(),
  });

  static const String lastTimetableAttemptDateKey =
      'academic.dailyAutoImport.lastTimetableAttemptDate';

  final AcademicCredentialService credentialService;
  final AcademicDailyAutoImportStore store;

  Future<bool> shouldRunDailyTimetableImport({DateTime? now}) async {
    final credential = await credentialService.load();
    if (credential == null || !credential.autoLoginEnabled) {
      return false;
    }

    final today = _localDateKey(now ?? DateTime.now());
    final lastAttemptDate = await store.read(lastTimetableAttemptDateKey);
    return lastAttemptDate != today;
  }

  Future<void> markDailyTimetableImportAttempted({DateTime? now}) {
    return store.write(
      key: lastTimetableAttemptDateKey,
      value: _localDateKey(now ?? DateTime.now()),
    );
  }

  String _localDateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
