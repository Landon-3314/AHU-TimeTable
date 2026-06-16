import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/clock_time.dart';
import 'package:AnKe/models/course.dart';
import 'package:AnKe/models/event.dart';
import 'package:AnKe/models/time_slot.dart';
import 'package:AnKe/services/schedule_plan.dart';

void main() {
  const slots = <TimeSlot>[
    TimeSlot(
      periodNumber: 1,
      startTime: ClockTime(hour: 8, minute: 0),
      endTime: ClockTime(hour: 8, minute: 45),
      label: 'Morning',
    ),
    TimeSlot(
      periodNumber: 2,
      startTime: ClockTime(hour: 8, minute: 55),
      endTime: ClockTime(hour: 9, minute: 40),
      label: 'Morning',
    ),
  ];

  test(
    'builds course reminders and native mute windows from semester weeks',
    () {
      final course = Course(
        id: 'course-1',
        name: '高等数学',
        location: 'A101',
        teacher: '张老师',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      );

      final plan = SchedulePlanBuilder.build(
        courses: [course],
        events: const [],
        timeSlots: slots,
        semesterStartDate: DateTime(2026, 4, 27),
        totalWeeks: 20,
        courseReminderAdvanceMinutes: 10,
        eventReminderAdvanceMinutes: 0,
        autoMuteEnabled: true,
        canAutoMute: true,
        now: DateTime(2026, 4, 27, 7, 0),
      );

      expect(plan.notifications, hasLength(1));
      expect(
        plan.notifications.single.kind,
        ManagedNotificationKind.courseReminder,
      );
      expect(
        plan.notifications.single.scheduledAt,
        DateTime(2026, 4, 27, 7, 50),
      );
      expect(plan.muteWindows, hasLength(1));
      expect(plan.muteWindows.single.startAt, DateTime(2026, 4, 27, 8, 0));
      expect(plan.muteWindows.single.endAt, DateTime(2026, 4, 27, 9, 40));
      expect(plan.muteWindows.single.shouldScheduleSilent, isTrue);
      expect(plan.todayCourses, hasLength(1));
      expect(plan.courseStatusWindows, hasLength(1));
      expect(
        plan.courseStatusWindows.single.startAt,
        DateTime(2026, 4, 27, 8, 0),
      );
    },
  );

  test('skips courses with invalid time slot hours', () {
    final course = Course(
      id: 'course-invalid-time',
      name: 'Invalid Time',
      location: 'A101',
      teacher: 'Teacher',
      weekday: DateTime.monday,
      weeks: const [1],
      startPeriod: 1,
      endPeriod: 1,
      colorValue: 0xFF7C9AF2,
    );

    final plan = SchedulePlanBuilder.build(
      courses: [course],
      events: const [],
      timeSlots: const [
        TimeSlot(
          periodNumber: 1,
          startTime: ClockTime(hour: 24, minute: 0),
          endTime: ClockTime(hour: 24, minute: 45),
          label: 'Evening',
        ),
      ],
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 10,
      eventReminderAdvanceMinutes: 0,
      autoMuteEnabled: true,
      canAutoMute: true,
      now: DateTime(2026, 4, 27, 7, 0),
    );

    expect(plan.notifications, isEmpty);
    expect(plan.courseAutomationWindows, isEmpty);
    expect(plan.todayCourses, isEmpty);
  });

  test('moves adjacent single-period reminder out of previous mute window', () {
    final courses = <Course>[
      Course(
        id: 'single-period-1',
        name: 'Course A',
        location: 'A101',
        teacher: 'Teacher A',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 1,
        colorValue: 0xFF7C9AF2,
      ),
      Course(
        id: 'single-period-2',
        name: 'Course B',
        location: 'B102',
        teacher: 'Teacher B',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 2,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      ),
    ];

    final plan = SchedulePlanBuilder.build(
      courses: courses,
      events: const [],
      timeSlots: slots,
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 10,
      eventReminderAdvanceMinutes: 0,
      autoMuteEnabled: true,
      canAutoMute: true,
      now: DateTime(2026, 4, 27, 7, 0),
    );

    expect(plan.notifications, hasLength(2));
    expect(
      plan.notifications.map((notification) => notification.scheduledAt),
      containsAllInOrder([
        DateTime(2026, 4, 27, 7, 50),
        DateTime(2026, 4, 27, 8, 45, 5),
      ]),
    );
    expect(plan.courseAutomationWindows, hasLength(2));
    expect(
      plan.courseAutomationWindows.map((window) => window.startAt),
      containsAllInOrder([
        DateTime(2026, 4, 27, 8, 0),
        DateTime(2026, 4, 27, 8, 55),
      ]),
    );
  });

  test('uses manual mute notification when automatic mute is unavailable', () {
    final course = Course(
      id: 'course-2',
      name: '大学英语',
      location: '',
      teacher: '李老师',
      weekday: DateTime.tuesday,
      weeks: const [1],
      startPeriod: 1,
      endPeriod: 1,
      colorValue: 0xFF7C9AF2,
    );

    final plan = SchedulePlanBuilder.build(
      courses: [course],
      events: const [],
      timeSlots: slots,
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 0,
      eventReminderAdvanceMinutes: 0,
      autoMuteEnabled: true,
      canAutoMute: false,
      now: DateTime(2026, 4, 27, 9, 0),
    );

    expect(plan.muteWindows, isEmpty);
    expect(plan.courseStatusWindows, hasLength(1));
    expect(plan.autoMuteFallbackEnabled, isTrue);
    expect(plan.notifications, hasLength(1));
    expect(plan.notifications.single.kind, ManagedNotificationKind.manualMute);
    expect(plan.notifications.single.scheduledAt, DateTime(2026, 4, 28, 8, 0));
  });

  test(
    'keeps restore window but does not schedule immediate mute for active class',
    () {
      final course = Course(
        id: 'course-active',
        name: '操作系统',
        location: 'C301',
        teacher: '赵老师',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      );

      final plan = SchedulePlanBuilder.build(
        courses: [course],
        events: const [],
        timeSlots: slots,
        semesterStartDate: DateTime(2026, 4, 27),
        totalWeeks: 20,
        courseReminderAdvanceMinutes: 10,
        eventReminderAdvanceMinutes: 0,
        autoMuteEnabled: true,
        canAutoMute: true,
        now: DateTime(2026, 4, 27, 8, 30),
      );

      expect(plan.notifications, isEmpty);
      expect(plan.courseAutomationWindows, hasLength(1));
      expect(
        plan.courseAutomationWindows.single.startAt,
        DateTime(2026, 4, 27, 8, 0),
      );
      expect(
        plan.courseAutomationWindows.single.endAt,
        DateTime(2026, 4, 27, 9, 40),
      );
      expect(plan.courseAutomationWindows.single.shouldScheduleSilent, isFalse);
    },
  );

  test(
    'keeps course reminders while falling back to manual mute without native permissions',
    () {
      final course = Course(
        id: 'course-fallback',
        name: '概率论',
        location: 'D401',
        teacher: '孙老师',
        weekday: DateTime.tuesday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 1,
        colorValue: 0xFF7C9AF2,
      );

      final plan = SchedulePlanBuilder.build(
        courses: [course],
        events: const [],
        timeSlots: slots,
        semesterStartDate: DateTime(2026, 4, 27),
        totalWeeks: 20,
        courseReminderAdvanceMinutes: 10,
        eventReminderAdvanceMinutes: 0,
        autoMuteEnabled: true,
        canAutoMute: false,
        now: DateTime(2026, 4, 27, 9, 0),
      );

      expect(plan.courseAutomationWindows, isEmpty);
      expect(
        plan.notifications.map((notification) => notification.kind),
        containsAllInOrder([
          ManagedNotificationKind.courseReminder,
          ManagedNotificationKind.manualMute,
        ]),
      );
      expect(
        plan.notifications.map((notification) => notification.scheduledAt),
        containsAllInOrder([
          DateTime(2026, 4, 28, 7, 50),
          DateTime(2026, 4, 28, 8, 0),
        ]),
      );
    },
  );

  test('filters expired courses and disabled event alarms', () {
    final course = Course(
      id: 'course-3',
      name: '线性代数',
      location: 'B201',
      teacher: '王老师',
      weekday: DateTime.monday,
      weeks: const [1],
      startPeriod: 1,
      endPeriod: 1,
      colorValue: 0xFF7C9AF2,
    );
    final event = Event(
      id: 'event-1',
      name: '班会',
      location: '会议室',
      dateTime: DateTime(2026, 4, 27, 20, 0),
      enableAlarm: false,
    );

    final plan = SchedulePlanBuilder.build(
      courses: [course],
      events: [event],
      timeSlots: slots,
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 10,
      eventReminderAdvanceMinutes: 10,
      autoMuteEnabled: true,
      canAutoMute: true,
      now: DateTime(2026, 4, 27, 10, 0),
    );

    expect(plan.notifications, isEmpty);
    expect(plan.muteWindows, isEmpty);
    expect(plan.todayCourses, hasLength(1));
  });

  test(
    'adds event reminders and caps notifications to the earliest entries',
    () {
      final events = List<Event>.generate(70, (index) {
        return Event(
          id: 'event-$index',
          name: '日程 $index',
          location: '',
          dateTime: DateTime(2026, 4, 28, 8, 0).add(Duration(minutes: index)),
          enableAlarm: true,
        );
      });

      final plan = SchedulePlanBuilder.build(
        courses: const [],
        events: events,
        timeSlots: slots,
        semesterStartDate: DateTime(2026, 4, 27),
        totalWeeks: 20,
        courseReminderAdvanceMinutes: 0,
        eventReminderAdvanceMinutes: 5,
        autoMuteEnabled: false,
        canAutoMute: false,
        now: DateTime(2026, 4, 27, 8, 0),
        maxNotificationCount: 60,
      );

      expect(plan.notifications, hasLength(60));
      expect(
        plan.notifications.first.scheduledAt,
        DateTime(2026, 4, 28, 7, 55),
      );
      expect(plan.notifications.last.scheduledAt, DateTime(2026, 4, 28, 8, 54));
      expect(
        plan.notifications.map((notification) => notification.id).toSet(),
        hasLength(60),
      );
    },
  );

  test('semester coverage horizon includes courses after day fourteen', () {
    final course = Course(
      id: 'course-week-3',
      name: '编译原理',
      location: 'E501',
      teacher: '周老师',
      weekday: DateTime.monday,
      weeks: const [3],
      startPeriod: 1,
      endPeriod: 1,
      colorValue: 0xFF7C9AF2,
    );

    final boundedPlan = SchedulePlanBuilder.build(
      courses: [course],
      events: const [],
      timeSlots: slots,
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 0,
      eventReminderAdvanceMinutes: 0,
      autoMuteEnabled: true,
      canAutoMute: true,
      now: DateTime(2026, 4, 27, 7, 0),
    );
    final semesterPlan = SchedulePlanBuilder.build(
      courses: [course],
      events: const [],
      timeSlots: slots,
      semesterStartDate: DateTime(2026, 4, 27),
      totalWeeks: 20,
      courseReminderAdvanceMinutes: 0,
      eventReminderAdvanceMinutes: 0,
      autoMuteEnabled: true,
      canAutoMute: true,
      now: DateTime(2026, 4, 27, 7, 0),
      horizonDays: SchedulePlanBuilder.semesterCoverageDays(20),
    );

    expect(boundedPlan.courseAutomationWindows, isEmpty);
    expect(semesterPlan.courseAutomationWindows, hasLength(1));
    expect(
      semesterPlan.courseAutomationWindows.single.startAt,
      DateTime(2026, 5, 11, 8, 0),
    );
  });

  test(
    'native fallback retains dormant mute window without duplicate reminder',
    () {
      final course = Course(
        id: 'course-native-fallback',
        name: '操作系统',
        location: 'E502',
        teacher: '吴老师',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 1,
        colorValue: 0xFF7C9AF2,
      );

      final plan = SchedulePlanBuilder.build(
        courses: [course],
        events: const [],
        timeSlots: slots,
        semesterStartDate: DateTime(2026, 4, 27),
        totalWeeks: 20,
        courseReminderAdvanceMinutes: 0,
        eventReminderAdvanceMinutes: 0,
        autoMuteEnabled: true,
        canAutoMute: false,
        retainAutoMuteWindows: true,
        nativeMuteFallbackEnabled: true,
        now: DateTime(2026, 4, 27, 7, 0),
      );

      expect(plan.courseAutomationWindows, hasLength(1));
      expect(
        plan.notifications.where(
          (item) => item.kind == ManagedNotificationKind.manualMute,
        ),
        isEmpty,
      );
      expect(plan.autoMuteFallbackEnabled, isTrue);
    },
  );
}
