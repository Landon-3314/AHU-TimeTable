import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../widgets/common/app_ui.dart';

const settingsSaveFailureMessage = '保存失败，请稍后重试';
const settingsReminderRefreshFailureMessage = '已保存，但提醒刷新失败';

Future<bool> runSettingsUpdateWithFeedback({
  required BuildContext context,
  required Future<void> Function() update,
  Future<void> Function()? afterPersisted,
  String debugLabel = 'SettingsUpdate',
}) async {
  try {
    await update();
  } on SettingsReminderRefreshException catch (error) {
    debugPrint('[$debugLabel] Reminder refresh failed after save: $error');
    if (context.mounted) {
      _showSettingsSnackBar(context, settingsReminderRefreshFailureMessage);
    }
    return false;
  } catch (error) {
    debugPrint('[$debugLabel] Failed to save settings: $error');
    if (context.mounted) {
      _showSettingsSnackBar(context, settingsSaveFailureMessage);
    }
    return false;
  }

  if (!context.mounted || afterPersisted == null) {
    return true;
  }

  try {
    await afterPersisted();
    return true;
  } catch (error) {
    debugPrint('[$debugLabel] Failed to refresh schedules after save: $error');
    if (context.mounted) {
      _showSettingsSnackBar(context, settingsReminderRefreshFailureMessage);
    }
    return false;
  }
}

void _showSettingsSnackBar(BuildContext context, String message) {
  showAppSnackBar(context, SnackBar(content: Text(message)));
}
