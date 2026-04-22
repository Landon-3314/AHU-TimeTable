import 'package:flutter/material.dart';

import '../models/course.dart';
import '../screens/add_course_page.dart';
import '../screens/developer_diagnostics_page.dart';
import '../screens/import_course_page.dart';
import '../screens/main_scaffold.dart';
import '../screens/reschedule_course_page.dart';
import '../screens/schedule_settings_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String addCourse = '/add-course';
  static const String rescheduleCourse = '/reschedule-course';
  static const String importCourses = '/import-courses';
  static const String scheduleSettings = '/schedule-settings';
  static const String developerDiagnostics = '/developer-diagnostics';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const MainScaffold(),
          settings: settings,
        );
      case addCourse:
        final arguments = settings.arguments;
        final existingCourse = arguments is AddCourseRouteArgs
            ? arguments.existingCourse
            : null;
        return MaterialPageRoute<void>(
          builder: (_) => AddCoursePage(existingCourse: existingCourse),
          settings: settings,
        );
      case rescheduleCourse:
        final arguments = settings.arguments;
        final routeArgs = arguments is RescheduleCourseRouteArgs
            ? arguments
            : null;
        if (routeArgs == null) {
          return MaterialPageRoute<void>(
            builder: (_) => const MainScaffold(),
            settings: settings,
          );
        }
        return MaterialPageRoute<bool>(
          builder: (_) => RescheduleCoursePage(
            course: routeArgs.course,
            sourceWeek: routeArgs.sourceWeek,
          ),
          settings: settings,
        );
      case importCourses:
        return MaterialPageRoute<int>(
          builder: (_) => const ImportCoursePage(),
          settings: settings,
        );
      case scheduleSettings:
        return MaterialPageRoute<void>(
          builder: (_) => const ScheduleSettingsPage(),
          settings: settings,
        );
      case developerDiagnostics:
        return MaterialPageRoute<void>(
          builder: (_) => const DeveloperDiagnosticsPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const MainScaffold(),
          settings: settings,
        );
    }
  }
}

class AddCourseRouteArgs {
  const AddCourseRouteArgs({this.existingCourse});

  final Course? existingCourse;
}

class RescheduleCourseRouteArgs {
  const RescheduleCourseRouteArgs({
    required this.course,
    required this.sourceWeek,
  });

  final Course course;
  final int sourceWeek;
}
