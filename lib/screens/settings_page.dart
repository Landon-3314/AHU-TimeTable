import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/long_screenshot_scroll_capture.dart';
import '../widgets/common/app_ui.dart';
import 'reminder_settings_page.dart';
import 'theme_settings_page.dart';
import 'timetable_time_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return SafeArea(
      child: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: AppSpacing.pagePadding,
          children: [
            Text(
              provider.t('settings'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSectionTitle(title: provider.t('appearance')),
            _buildAppearanceSection(context),
            const SizedBox(height: AppSpacing.xl),
            AppSectionTitle(title: provider.t('notifications')),
            _buildAutomationAndNotificationSection(context),
            const SizedBox(height: AppSpacing.xl),
            AppSectionTitle(title: provider.t('basic_settings')),
            _buildTimetableParamsSection(context),
            const SizedBox(height: AppSpacing.xl),
            AppSectionTitle(title: provider.t('data_storage')),
            _buildDataSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return AppSurface(
      child: AppActionTile(
        icon: Icons.palette_outlined,
        title: provider.t('theme_color'),
        subtitle: provider.t(provider.themePalette.nameKey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ThemeSettingsPage()),
          );
        },
      ),
    );
  }

  Widget _buildAutomationAndNotificationSection(BuildContext context) {
    return AppSurface(
      child: AppActionTile(
        icon: Icons.notifications_active_outlined,
        title: '上课静音与提醒',
        subtitle: '配置自动静音与课前提醒',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReminderSettingsPage(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimetableParamsSection(BuildContext context) {
    return AppSurface(
      child: AppActionTile(
        icon: Icons.calendar_today_outlined,
        title: '学期与时间配置',
        subtitle: '管理学期、周数、节次和课间时长',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TimetableTimeSettingsPage(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.cookie_outlined),
              label: Text(provider.t('clear_browser_cache')),
              onPressed: () => _confirmAndClearCookies(context),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(provider.t('clear_all_local_data')),
              onPressed: () => _confirmAndClearAllData(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndClearCookies(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: provider.t('clear_browser_cache'),
      message: provider.t('clear_browser_cache_subtitle'),
      confirmLabel: provider.t('confirm'),
      cancelLabel: provider.t('cancel'),
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final cleared = await WebViewCookieManager().clearCookies();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleared ? provider.t('cache_cleared') : '无 Cookies 可删除'),
      ),
    );
  }

  Future<void> _confirmAndClearAllData(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: provider.t('confirm_clear'),
      message: provider.t('confirm_clear_message'),
      confirmLabel: provider.t('confirm'),
      cancelLabel: provider.t('cancel'),
      danger: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    await context.read<CourseProvider>().clearAllData();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.t('all_local_data_cleared'))),
    );
  }
}
