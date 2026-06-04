import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../providers/settings_provider.dart';
import 'daily_academic_auto_import_host.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices =>
      Set<PointerDeviceKind>.from(PointerDeviceKind.values);
}

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key, required this.settingsProvider});

  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    final palette = settingsProvider.themePalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(palette: palette),
      darkTheme: AppTheme.dark(palette: palette),
      themeMode: settingsProvider.materialThemeMode,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        return DailyAcademicAutoImportHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
