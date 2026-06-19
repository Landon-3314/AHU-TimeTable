import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../models/academic_credential.dart';
import '../models/academic_import.dart';
import '../providers/settings_provider.dart';
import '../services/academic_credential_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/semester_initialization_guard.dart';
import 'import_course_page.dart';

typedef AcademicAutoImportLauncher =
    Future<AcademicImportResult?> Function(
      BuildContext context,
      AcademicAutoAction action,
    );

typedef AcademicManualImportLauncher =
    Future<AcademicImportResult?> Function(BuildContext context);

typedef AcademicSilentAutoImportBuilder =
    Widget Function(
      BuildContext context,
      AcademicAutoAction action,
      ValueChanged<AcademicImportResult> onResult,
      ValueChanged<String> onError,
    );

class AcademicAccountPage extends StatefulWidget {
  const AcademicAccountPage({
    super.key,
    this.credentialService = const AcademicCredentialService(),
    this.autoImportLauncher,
    this.manualImportLauncher,
    this.silentAutoImportBuilder,
  });

  final AcademicCredentialService credentialService;
  final AcademicAutoImportLauncher? autoImportLauncher;
  final AcademicManualImportLauncher? manualImportLauncher;
  final AcademicSilentAutoImportBuilder? silentAutoImportBuilder;

  @override
  State<AcademicAccountPage> createState() => _AcademicAccountPageState();
}

class _AcademicAccountPageState extends State<AcademicAccountPage> {
  static const int _maxSilentAutoImportRecoverableRetries = 1;

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _autoLoginEnabled = true;
  bool _isLoading = true;
  bool _isBusy = false;
  AcademicAutoAction? _silentAutoAction;
  int _silentAutoImportRunId = 0;
  int _silentAutoImportRetryCount = 0;

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
      body: Stack(
        children: [
          ListView(
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
                          onPressed: _isBusy || _isLoading
                              ? null
                              : _saveCredential,
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
              AppSectionTitle(
                title: settingsProvider.t('academic_import_actions'),
              ),
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
                      subtitle: settingsProvider.t(
                        'auto_extract_exam_subtitle',
                      ),
                      enabled: !_isBusy && !_isLoading,
                      onTap: () => _runAutoImport(AcademicAutoAction.exam),
                    ),
                    AppActionTile(
                      icon: Icons.grade_outlined,
                      title: settingsProvider.t('auto_extract_grade'),
                      subtitle: settingsProvider.t(
                        'auto_extract_grade_subtitle',
                      ),
                      enabled: !_isBusy && !_isLoading,
                      onTap: () => _runAutoImport(AcademicAutoAction.grade),
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
          if (_silentAutoAction != null)
            Positioned(
              left: -2,
              top: -2,
              width: 1,
              height: 1,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.01,
                  child: KeyedSubtree(
                    key: ValueKey('silent-auto-import-$_silentAutoImportRunId'),
                    child: _buildSilentAutoImporter(_silentAutoAction!),
                  ),
                ),
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

    if (action != AcademicAutoAction.grade &&
        !(await ensureCurrentSemesterInitialized(context))) {
      return;
    }
    if (!mounted) {
      return;
    }

    final launcher = widget.autoImportLauncher;
    if (launcher == null) {
      _startSilentAutoImport(action);
      return;
    }

    final result = await launcher(context, action);
    if (!mounted || result == null) {
      return;
    }
    _showSnackBar(
      _buildImportSummary(context.read<SettingsProvider>(), result),
    );
  }

  Future<void> _runManualImport() async {
    if (!await ensureCurrentSemesterInitialized(context)) {
      return;
    }
    if (!mounted) {
      return;
    }

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

  Future<AcademicImportResult?> _defaultManualImportLauncher(
    BuildContext context,
  ) {
    return Navigator.of(context).push<AcademicImportResult>(
      MaterialPageRoute<AcademicImportResult>(
        builder: (_) => const ImportCoursePage(),
      ),
    );
  }

  void _startSilentAutoImport(AcademicAutoAction action) {
    final settingsProvider = context.read<SettingsProvider>();
    setState(() {
      _isBusy = true;
      _silentAutoAction = action;
      _silentAutoImportRunId += 1;
      _silentAutoImportRetryCount = 0;
    });
    _showSnackBar(
      settingsProvider.t(switch (action) {
        AcademicAutoAction.exam => 'auto_exam_import_opening',
        AcademicAutoAction.grade => 'auto_grade_import_opening',
        AcademicAutoAction.timetable => 'auto_import_opening',
      }),
    );
  }

  Widget _buildSilentAutoImporter(AcademicAutoAction action) {
    final builder =
        widget.silentAutoImportBuilder ?? _defaultSilentAutoImportBuilder;
    return builder(
      context,
      action,
      _handleSilentAutoImportResult,
      _handleSilentAutoImportError,
    );
  }

  Widget _defaultSilentAutoImportBuilder(
    BuildContext context,
    AcademicAutoAction action,
    ValueChanged<AcademicImportResult> onResult,
    ValueChanged<String> onError,
  ) {
    return ImportCoursePage(
      initialAutoAction: action,
      showWebView: false,
      onImportResult: onResult,
      onImportError: onError,
    );
  }

  void _handleSilentAutoImportResult(AcademicImportResult result) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _silentAutoAction = null;
      _silentAutoImportRetryCount = 0;
    });
    _showSnackBar(
      _buildImportSummary(context.read<SettingsProvider>(), result),
    );
  }

  void _handleSilentAutoImportError(String message) {
    if (!mounted) {
      return;
    }
    if (_silentAutoAction != null &&
        _silentAutoImportRetryCount < _maxSilentAutoImportRecoverableRetries &&
        isRecoverableAcademicAutoImportError(message)) {
      setState(() {
        _silentAutoImportRetryCount += 1;
        _silentAutoImportRunId += 1;
      });
      _showSnackBar(context.read<SettingsProvider>().t('auto_import_retrying'));
      return;
    }

    setState(() {
      _isBusy = false;
      _silentAutoAction = null;
      _silentAutoImportRetryCount = 0;
    });
    _showSnackBar(message);
  }

  String _buildImportSummary(
    SettingsProvider settingsProvider,
    AcademicImportResult result,
  ) {
    if (result.kind == AcademicImportKind.exam) {
      if (result.importedCount == 0 && result.skippedReasons.isNotEmpty) {
        return result.skippedReasons.first;
      }
      return settingsProvider
          .t('exam_import_success_format')
          .replaceAll('{count}', result.importedCount.toString());
    }
    if (result.kind == AcademicImportKind.grade) {
      return settingsProvider
          .t('grade_import_success_format')
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
