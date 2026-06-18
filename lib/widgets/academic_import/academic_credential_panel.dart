import 'package:flutter/material.dart';

import '../../models/academic_credential.dart';
import '../../providers/settings_provider.dart';

class AcademicCredentialPanel extends StatelessWidget {
  const AcademicCredentialPanel({
    super.key,
    required this.settingsProvider,
    required this.studentIdController,
    required this.passwordController,
    required this.isBusy,
    required this.isCredentialLoading,
    required this.autoLoginEnabled,
    required this.storedCredential,
    required this.status,
    required this.onAutoLoginChanged,
    required this.onSaveCredential,
    required this.onClearCredential,
    required this.onRunTimetableImport,
    required this.onRunExamImport,
  });

  final SettingsProvider settingsProvider;
  final TextEditingController studentIdController;
  final TextEditingController passwordController;
  final bool isBusy;
  final bool isCredentialLoading;
  final bool autoLoginEnabled;
  final AcademicCredential? storedCredential;
  final String? status;
  final ValueChanged<bool> onAutoLoginChanged;
  final VoidCallback onSaveCredential;
  final VoidCallback onClearCredential;
  final VoidCallback onRunTimetableImport;
  final VoidCallback onRunExamImport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: studentIdController,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: settingsProvider.t('academic_student_id'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: passwordController,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: settingsProvider.t('academic_password'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    autofillHints: const [AutofillHints.password],
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(settingsProvider.t('academic_auto_login_enabled')),
              subtitle: Text(settingsProvider.t('academic_credentials_notice')),
              value: autoLoginEnabled,
              onChanged: isBusy || isCredentialLoading
                  ? null
                  : onAutoLoginChanged,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isBusy || isCredentialLoading
                      ? null
                      : onSaveCredential,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(settingsProvider.t('save_academic_credentials')),
                ),
                if (storedCredential != null)
                  TextButton.icon(
                    onPressed: isBusy ? null : onClearCredential,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      settingsProvider.t('clear_academic_credentials'),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: isBusy || isCredentialLoading
                      ? null
                      : onRunTimetableImport,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(settingsProvider.t('auto_login_extract')),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || isCredentialLoading
                      ? null
                      : onRunExamImport,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(settingsProvider.t('auto_login_extract_exam')),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
