import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../models/event.dart';
import '../providers/course_provider.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/timetable/timetable_detail_sheets.dart';

class ExamOverviewPage extends StatelessWidget {
  const ExamOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final exams =
        courseProvider.events
            .where(
              (event) =>
                  event.importSource == CourseProvider.academicExamImportSource,
            )
            .toList()
          ..sort((left, right) => left.dateTime.compareTo(right.dateTime));

    return Scaffold(
      appBar: AppBar(title: const Text('教务考试')),
      body: exams.isEmpty
          ? AppEmptyState(
              icon: Icons.assignment_outlined,
              title: '暂无教务考试',
              subtitle: '从教务系统导入考试后，会在这里集中展示。',
              action: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.importCourses),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('导入考试'),
              ),
            )
          : ListView.separated(
              padding: AppSpacing.pagePadding,
              itemCount: exams.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
              itemBuilder: (context, index) {
                return _ExamCard(event: exams[index]);
              },
            ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final importedAt = event.importedAt;
    return AppSurface(
      child: InkWell(
        onTap: () => showEventDetailsSheet(context, event),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    examCountdownLabel(event.dateTime, DateTime.now()),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(DateFormat('yyyy/MM/dd HH:mm').format(event.dateTime)),
              const SizedBox(height: AppSpacing.sm),
              Text('地点：${_displayOrFallback(event.location)}'),
              const SizedBox(height: AppSpacing.sm),
              Text('座位或备注：${_displayOrFallback(event.note)}'),
              const SizedBox(height: AppSpacing.sm),
              const Text('教务系统'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '最近导入：${importedAt == null ? '未知' : DateFormat('yyyy/MM/dd HH:mm').format(importedAt)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String examCountdownLabel(DateTime examTime, DateTime now) {
  final examDate = DateTime(examTime.year, examTime.month, examTime.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = examDate.difference(today).inDays;
  if (days < 0) {
    return '已结束';
  }
  if (days == 0) {
    return '今天';
  }
  return '还有 $days 天';
}

String _displayOrFallback(String value) {
  return value.trim().isEmpty ? '未设置' : value;
}
