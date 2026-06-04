import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../models/academic_credential.dart';
import '../providers/settings_provider.dart';
import '../services/academic_credential_service.dart';
import '../widgets/common/app_ui.dart';
import 'import_course_page.dart';

typedef AcademicAutoImportLauncher =
    Future<AcademicImportResult?> Function(
      BuildContext context,
      AcademicAutoAction action,
    );

typedef AcademicManualImportLauncher =
    Future<AcademicImportResult?> Function(BuildContext context);

class AcademicAccountPage extends StatefulWidget {
  const AcademicAccountPage({
    super.key,
    this.credentialService = const AcademicCredentialService(),
    this.autoImportLauncher,
    this.manualImportLauncher,
  });

  final AcademicCredentialService credentialService;
  final AcademicAutoImportLauncher? autoImportLauncher;
  final AcademicManualImportLauncher? manualImportLauncher;

  @override
  State<AcademicAccountPage> createState() => _AcademicAccountPageState();
}

class _AcademicAccountPageState extends State<AcademicAccountPage> {
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _autoLoginEnabled = true;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCredential());
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.t('academic_account_title'))),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          AppSectionTitle(
            title: settingsProvider.t('academic_account_section'),
            subtitle: settingsProvider.t('academic_credentials_notice'),
          ),
          AppSurface(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _studentIdController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(
                    labelText: settingsProvider.t('academic_student_id'),
                    border: const OutlineInputBorder(),
                  ),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _passwordController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(
                    labelText: settingsProvider.t('academic_password'),
                    border: const OutlineInputBorder(),
                  ),
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    settingsProvider.t('academic_auto_login_enabled'),
                  ),
                  value: _autoLoginEnabled,
                  onChanged: _isBusy || _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _autoLoginEnabled = value;
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _isBusy || _isLoading ? null : _saveCredential,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        settingsProvider.t('save_academic_credentials'),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isBusy || _isLoading
                          ? null
                          : _clearCredential,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        settingsProvider.t('clear_academic_credentials'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionTitle(title: settingsProvider.t('academic_import_actions')),
          AppSurface(
            child: Column(
              children: [
                AppActionTile(
                  icon: Icons.download_for_offline_outlined,
                  title: settingsProvider.t('auto_extract_timetable'),
                  subtitle: settingsProvider.t(
                    'auto_extract_timetable_subtitle',
                  ),
                  enabled: !_isBusy && !_isLoading,
                  onTap: () => _runAutoImport(AcademicAutoAction.timetable),
                ),
                AppActionTile(
                  icon: Icons.assignment_outlined,
                  title: settingsProvider.t('auto_extract_exam'),
                  subtitle: settingsProvider.t('auto_extract_exam_subtitle'),
                  enabled: !_isBusy && !_isLoading,
                  onTap: () => _runAutoImport(AcademicAutoAction.exam),
                ),
                AppActionTile(
                  icon: Icons.open_in_browser_outlined,
                  title: settingsProvider.t('manual_academic_import'),
                  subtitle: settingsProvider.t(
                    'manual_academic_import_subtitle',
                  ),
                  enabled: !_isBusy && !_isLoading,
                  onTap: _runManualImport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCredential() async {
    final credential = await widget.credentialService.load();
    if (!mounted) {
      return;
    }

    if (credential != null) {
      _studentIdController.text = credential.studentId;
      _passwordController.text = credential.password;
    }
    setState(() {
      _autoLoginEnabled = credential?.autoLoginEnabled ?? true;
      _isLoading = false;
    });
  }

  AcademicCredential? _credentialFromInput() {
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;
    if (studentId.isEmpty || password.isEmpty) {
      return null;
    }
    return AcademicCredential(
      studentId: studentId,
      password: password,
      autoLoginEnabled: _autoLoginEnabled,
    );
  }

  Future<bool> _saveCredential({bool showMessage = true}) async {
    final settingsProvider = context.read<SettingsProvider>();
    final credential = _credentialFromInput();
    if (credential == null) {
      _showSnackBar(settingsProvider.t('academic_credentials_empty'));
      return false;
    }

    setState(() {
      _isBusy = true;
    });
    await widget.credentialService.save(credential);
    if (!mounted) {
      return false;
    }
    setState(() {
      _isBusy = false;
    });
    if (showMessage) {
      _showSnackBar(settingsProvider.t('academic_credentials_saved'));
    }
    return true;
  }

  Future<void> _clearCredential() async {
    final settingsProvider = context.read<SettingsProvider>();
    setState(() {
      _isBusy = true;
    });
    await widget.credentialService.clear();
    if (!mounted) {
      return;
    }
    _studentIdController.clear();
    _passwordController.clear();
    setState(() {
      _autoLoginEnabled = true;
      _isBusy = false;
    });
    _showSnackBar(settingsProvider.t('academic_credentials_cleared'));
  }

  Future<void> _runAutoImport(AcademicAutoAction action) async {
    final saved = await _saveCredential(showMessage: false);
    if (!saved || !mounted) {
      return;
    }

    final launcher = widget.autoImportLauncher ?? _defaultAutoImportLauncher;
    final result = await launcher(context, action);
    if (!mounted || result == null) {
      return;
    }
    _showSnackBar(
      _buildImportSummary(context.read<SettingsProvider>(), result),
    );
  }

  Future<void> _runManualImport() async {
    final launcher =
        widget.manualImportLauncher ?? _defaultManualImportLauncher;
    final result = await launcher(context);
    if (!mounted || result == null) {
      return;
    }
    _showSnackBar(
      _buildImportSummary(context.read<SettingsProvider>(), result),
    );
  }

  Future<AcademicImportResult?> _defaultAutoImportLauncher(
    BuildContext context,
    AcademicAutoAction action,
  ) {
    return Navigator.of(context).push<AcademicImportResult>(
      MaterialPageRoute<AcademicImportResult>(
        builder: (_) =>
            ImportCoursePage(initialAutoAction: action, showWebView: false),
      ),
    );
  }

  Future<AcademicImportResult?> _defaultManualImportLauncher(
    BuildContext context,
  ) {
    return Navigator.of(context).push<AcademicImportResult>(
      MaterialPageRoute<AcademicImportResult>(
        builder: (_) => const ImportCoursePage(),
      ),
    );
  }

  String _buildImportSummary(
    SettingsProvider settingsProvider,
    AcademicImportResult result,
  ) {
    if (result.kind == AcademicImportKind.exam) {
      return settingsProvider
          .t('exam_import_success_format')
          .replaceAll('{count}', result.importedCount.toString());
    }

    var summary = settingsProvider
        .t('timetable_import_success_format')
        .replaceAll('{count}', result.importedCount.toString());
    if (result.skippedCount > 0) {
      summary = settingsProvider
          .t('timetable_import_skipped_format')
          .replaceAll('{summary}', summary)
          .replaceAll('{count}', result.skippedCount.toString())
          .replaceAll('{reasons}', result.skippedReasons.join('；'));
    }
    return summary;
  }

  void _showSnackBar(String message) {
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }
}
