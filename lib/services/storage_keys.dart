part of 'storage_service.dart';

const String _coursesKey = 'courses.items';
const String _eventsKey = 'events.items';
const String _academicGradesKey = 'academic.grades.v1';
const String _semestersKey = 'semesters.items';
const String _currentSemesterIdKey = 'semesters.currentId';
const String _semesterMigrationVersionKey = 'semesters.migrationVersion';
const String _semesterMigrationStateKey = 'semesters.migrationState';
const String _semesterMigrationTargetIdKey = 'semesters.migrationTargetId';
const String _semesterOperationJournalKey = 'semesters.operationJournal';
const String _semesterOperationCreate = 'create';
const String _semesterOperationInitialize = 'initialize';
const String _semesterOperationSwitch = 'switch';
const String _semesterOperationDelete = 'delete';
const int _semesterMigrationVersion = 1;
const String _migrationStateInProgress = 'in_progress';
const String _migrationStateComplete = 'complete';
const String _pixelsPerMinuteKey = 'settings.pixelsPerMinute';
const String _classDurationKey = 'settings.classDuration';
const String _shortBreakKey = 'settings.shortBreak';
const String _bigBreakEnabledKey = 'settings.bigBreakEnabled';
const String _bigBreakKey = 'settings.bigBreak';
const String _bigBreakAfterPeriodKey = 'settings.bigBreakAfterPeriod';
const String _bigBreakAfterPeriodsKey = 'settings.bigBreakAfterPeriods';
const String _morningStartTimeKey = 'settings.morningStartTime';
const String _morningClassesKey = 'settings.morningClasses';
const String _morningPeriodStartTimesKey = 'settings.morningPeriodStartTimes';
const String _afternoonStartTimeKey = 'settings.afternoonStartTime';
const String _afternoonClassesKey = 'settings.afternoonClasses';
const String _afternoonPeriodStartTimesKey =
    'settings.afternoonPeriodStartTimes';
const String _eveningStartTimeKey = 'settings.eveningStartTime';
const String _eveningClassesKey = 'settings.eveningClasses';
const String _eveningPeriodStartTimesKey = 'settings.eveningPeriodStartTimes';
const String _semesterStartDateKey = 'settings.semesterStartDate';
const String _semesterStartDatePromptShownKey =
    'settings.semesterStartDatePromptShown';
const String _timetableToolbarGuideConfirmedKey =
    'onboarding.timetableToolbarGuideConfirmed.v1';
const String _importWebViewGuideConfirmedKey =
    'onboarding.importWebViewGuideConfirmed.v1';
const String _timetableMenuGuideConfirmedKey =
    'onboarding.timetableMenuGuideConfirmed.v1';
const String _totalWeeksKey = 'settings.totalWeeks';
const String _reminderAdvanceMinutesKey = 'settings.reminderAdvanceMinutes';
const String _eventReminderAdvanceMinutesKey =
    'settings.eventReminderAdvanceMinutes';
const String _languageCodeKey = 'settings.languageCode';
const String _appThemeModeKey = 'settings.appThemeMode';
const String _themePaletteIdKey = 'settings.themePaletteId';
const String _customThemePrimaryValueKey = 'settings.customThemePrimaryValue';
const String _customThemeAccentValueKey = 'settings.customThemeAccentValue';
const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';
const String _courseReminderPersistentDisplayEnabledKey =
    'settings.courseReminderPersistentDisplayEnabled';
// Legacy key from the former standalone foreground-service switch.
const String _legacyBackgroundServiceEnabledKey =
    'settings.backgroundServiceEnabled';
