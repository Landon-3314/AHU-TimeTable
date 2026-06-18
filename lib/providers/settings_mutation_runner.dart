import 'package:flutter/foundation.dart';

class SettingsMutationRunner {
  const SettingsMutationRunner();

  Future<void> commit({
    required VoidCallback notifyListeners,
    required VoidCallback restore,
    required Future<void> Function() persist,
    Future<void> Function()? compensate,
    Future<void> Function()? refreshAfterPersistence,
  }) async {
    notifyListeners();
    try {
      await persist();
    } catch (error, stackTrace) {
      restore();
      try {
        await compensate?.call();
      } catch (compensationError) {
        debugPrint(
          '[SettingsProvider] Failed to compensate persisted settings: '
          '$compensationError',
        );
      }
      notifyListeners();
      Error.throwWithStackTrace(error, stackTrace);
    }
    await refreshAfterPersistence?.call();
  }
}
