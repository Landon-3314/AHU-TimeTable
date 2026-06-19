import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';
import '../../models/grade.dart';
import '../../providers/grade_provider.dart';
import '../common/app_ui.dart';

class GradeOverviewPanel extends StatelessWidget {
  const GradeOverviewPanel({super.key, this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final book = context.watch<GradeProvider>().gradeBook;
    if (book == null || book.isEmpty) {
      return AppEmptyState(
        icon: Icons.grade_outlined,
        title: '暂无教务成绩',
        subtitle: '从教务系统提取成绩后，会按学期展示课程成绩、GPA 和排名。',
        action: FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('提取成绩'),
        ),
      );
    }
    final terms = book.terms.toList()..sort(_compareGradeTermsDescending);

    return SafeArea(
      child: ListView(
        padding: AppSpacing.listPagePadding,
        children: [
          _GradeSummaryCard(statistics: book.statistics),
          const SizedBox(height: AppSpacing.md),
          for (final term in terms) ...[
            _GradeTermCard(term: term),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _GradeSummaryCard extends StatelessWidget {
  const _GradeSummaryCard({required this.statistics});

  final GradeStatistics? statistics;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '全程成绩',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MetricChip(
                  label: '全程 GPA',
                  value: _formatDouble(statistics?.gpa) ?? '--',
                ),
                _MetricChip(
                  label: '排名',
                  value: _formatRank(statistics) ?? '--',
                ),
                if (statistics?.totalCredits != null)
                  _MetricChip(
                    label: '总学分',
                    value: _formatDouble(statistics?.totalCredits) ?? '--',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeTermCard extends StatelessWidget {
  const _GradeTermCard({required this.term});

  final GradeTerm term;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final stats = [
      if (term.statistics?.gpa != null)
        'GPA ${_formatDouble(term.statistics?.gpa)}',
      if (_formatRank(term.statistics) != null)
        '排名 ${_formatRank(term.statistics)}',
      if (term.statistics?.totalCredits != null)
        '${_formatDouble(term.statistics?.totalCredits)} 学分',
    ].join(' · ');
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.semesterName.isEmpty
                  ? '学期 ${term.remoteSemesterId}'
                  : term.semesterName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(stats, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final record in term.records) _GradeRecordTile(record: record),
          ],
        ),
      ),
    );
  }
}

class _GradeRecordTile extends StatelessWidget {
  const _GradeRecordTile({required this.record});

  final GradeRecord record;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final meta = [
      if (record.credits != null) '${_formatDouble(record.credits)} 学分',
      if (record.gp != null) '绩点 ${_formatDouble(record.gp)}',
      if (record.courseType != null) record.courseType!,
      if (record.courseProperty != null) record.courseProperty!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(meta, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            record.grade ?? '--',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Center(
        child: Text(
          '$label $value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

int _compareGradeTermsDescending(GradeTerm a, GradeTerm b) {
  final aKey = _gradeTermSortKey(a);
  final bKey = _gradeTermSortKey(b);
  if (aKey != null && bKey != null) {
    return bKey.compareTo(aKey);
  }
  if (aKey != null) {
    return -1;
  }
  if (bKey != null) {
    return 1;
  }
  return _gradeTermTitle(b).compareTo(_gradeTermTitle(a));
}

int? _gradeTermSortKey(GradeTerm term) {
  return _sortKeyFromSemesterText(term.semesterName) ??
      _sortKeyFromSemesterText(
        [term.schoolYear, term.term].whereType<String>().join('-'),
      ) ??
      _sortKeyFromSemesterText(term.remoteSemesterId);
}

String _gradeTermTitle(GradeTerm term) {
  return term.semesterName.isEmpty
      ? '学期 ${term.remoteSemesterId}'
      : term.semesterName;
}

int? _sortKeyFromSemesterText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final separated = RegExp(
    r'((?:19|20)\d{2})\D+(?:19|20)\d{2}\D+([12])',
  ).firstMatch(normalized);
  if (separated != null) {
    return _semesterSortKey(separated.group(1), separated.group(2));
  }

  final compactText = normalized.replaceAll(RegExp(r'\D'), '');
  final compact = RegExp(
    r'((?:19|20)\d{2})(?:19|20)\d{2}([12])',
  ).firstMatch(compactText);
  if (compact != null) {
    return _semesterSortKey(compact.group(1), compact.group(2));
  }

  final yearOnly = RegExp(
    r'((?:19|20)\d{2})\D+(?:19|20)\d{2}',
  ).firstMatch(normalized);
  final termHint = _termNumberHint(normalized);
  if (yearOnly != null && termHint != null) {
    return _semesterSortKey(yearOnly.group(1), '$termHint');
  }
  return null;
}

int? _semesterSortKey(String? startYearText, String? termText) {
  final startYear = int.tryParse(startYearText ?? '');
  final term = int.tryParse(termText ?? '');
  if (startYear == null || term == null) {
    return null;
  }
  return startYear * 10 + term;
}

int? _termNumberHint(String text) {
  if (text.contains('春') || text.contains('第二') || text.contains('下')) {
    return 2;
  }
  if (text.contains('秋') || text.contains('第一') || text.contains('上')) {
    return 1;
  }
  return null;
}

String? _formatDouble(double? value) {
  if (value == null) {
    return null;
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

String? _formatRank(GradeStatistics? statistics) {
  final rank = statistics?.rank;
  if (rank == null) {
    return null;
  }
  final total = statistics?.rankTotal;
  return total == null ? rank.toString() : '$rank/$total';
}
