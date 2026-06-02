import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';
import '../../providers/course_provider.dart';
import '../common/app_ui.dart';

class CourseOverviewPanel extends StatelessWidget {
  const CourseOverviewPanel({
    super.key,
    required this.courseGroups,
    required this.groupCountLabelBuilder,
    required this.onCourseGroupTap,
    this.emptyAction,
  });

  final List<CourseGroup> courseGroups;
  final String Function(CourseGroup group) groupCountLabelBuilder;
  final ValueChanged<CourseGroup> onCourseGroupTap;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (courseGroups.isEmpty) {
      return AppEmptyState(
        icon: Icons.school_outlined,
        title: '本学期没有课程',
        subtitle: '本学期暂无课程安排。',
        action: emptyAction,
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: AppSpacing.listPagePadding,
        itemCount: courseGroups.length,
        itemBuilder: (context, index) {
          final group = courseGroups[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _CourseGroupTile(
              group: group,
              countLabel: groupCountLabelBuilder(group),
              onTap: () => onCourseGroupTap(group),
            ),
          );
        },
      ),
    );
  }
}

class _CourseGroupTile extends StatelessWidget {
  const _CourseGroupTile({
    required this.group,
    required this.countLabel,
    required this.onTap,
  });

  final CourseGroup group;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final accentColor = Color(group.courses.first.colorValue);
    return AppSurface(
      padding: EdgeInsets.zero,
      borderColor: accentColor.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _AccentBlock(color: accentColor),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _CountBadge(text: countLabel, color: accentColor),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentBlock extends StatelessWidget {
  const _AccentBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 58,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
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
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
