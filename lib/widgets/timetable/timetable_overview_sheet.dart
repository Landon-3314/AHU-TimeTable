import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../providers/course_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/exam_overview_page.dart';
import 'course_overview_panel.dart';
import 'grade_overview_panel.dart';
import 'pill_tab_switcher.dart';
import 'timetable_empty_state_actions.dart';

enum TimetableOverviewPage { courses, exams, grades }

class TimetableOverviewSheet extends StatefulWidget {
  const TimetableOverviewSheet({
    super.key,
    required this.groupCountLabelBuilder,
    required this.onAddCourse,
    required this.onImportCourses,
    required this.onCourseGroupTap,
  });

  final String Function(SettingsProvider settingsProvider, CourseGroup group)
  groupCountLabelBuilder;
  final VoidCallback onAddCourse;
  final VoidCallback onImportCourses;
  final ValueChanged<CourseGroup> onCourseGroupTap;

  @override
  State<TimetableOverviewSheet> createState() => TimetableOverviewSheetState();
}

class TimetableOverviewSheetState extends State<TimetableOverviewSheet> {
  final PageController _pageController = PageController();
  TimetableOverviewPage _selectedPage = TimetableOverviewPage.courses;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(TimetableOverviewPage page) {
    if (page == _selectedPage) {
      return;
    }
    _pageController.animateToPage(
      page.index,
      duration: AppDurations.switcher,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: _TimetableOverviewTabs(
            selectedPage: _selectedPage,
            onSelected: _selectPage,
          ),
        ),
        Expanded(
          child: PageView(
            key: const ValueKey('overview-pages'),
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedPage = TimetableOverviewPage.values[index];
              });
            },
            children: [
              CourseOverviewPanel(
                courseGroups: courseProvider.sortedCourseGroups,
                groupCountLabelBuilder: (group) =>
                    widget.groupCountLabelBuilder(settingsProvider, group),
                emptyAction: TimetableEmptyStateActions(
                  addCourseLabel: settingsProvider.t('add_course_or_event'),
                  importCoursesLabel: settingsProvider.t('import_from_system'),
                  showImportCourses: true,
                  onAddCourse: widget.onAddCourse,
                  onImportCourses: widget.onImportCourses,
                ),
                onCourseGroupTap: widget.onCourseGroupTap,
              ),
              ExamOverviewPanel(onImport: widget.onImportCourses),
              GradeOverviewPanel(onImport: widget.onImportCourses),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimetableOverviewTabs extends StatelessWidget {
  const _TimetableOverviewTabs({
    required this.selectedPage,
    required this.onSelected,
  });

  final TimetableOverviewPage selectedPage;
  final ValueChanged<TimetableOverviewPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return PillTabSwitcher<TimetableOverviewPage>(
      key: const ValueKey('overview-tabs'),
      indicatorKey: const ValueKey('overview-tabs-indicator'),
      selectedValue: selectedPage,
      itemWidth: 72,
      items: const [
        PillTabItem<TimetableOverviewPage>(
          key: ValueKey('overview-tab-courses'),
          value: TimetableOverviewPage.courses,
          label: Text('课程'),
        ),
        PillTabItem<TimetableOverviewPage>(
          key: ValueKey('overview-tab-exams'),
          value: TimetableOverviewPage.exams,
          label: Text('考试'),
        ),
        PillTabItem<TimetableOverviewPage>(
          key: ValueKey('overview-tab-grades'),
          value: TimetableOverviewPage.grades,
          label: Text('成绩'),
        ),
      ],
      onSelected: onSelected,
    );
  }
}
