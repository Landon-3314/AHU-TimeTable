package com.gh.timetable

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.util.Log
import java.util.TimeZone

object NativeAlarmScheduler {
    const val PREFS = "native_alarm_prefs"

    const val ACTION_SILENT = "com.timetable.ACTION_SILENT"
    const val ACTION_RESTORE = "com.timetable.ACTION_RESTORE"
    const val ACTION_REMIND_CLASS = "com.timetable.ACTION_REMIND_CLASS"
    const val ACTION_REMIND_SCHEDULE = "com.timetable.ACTION_REMIND_SCHEDULE"

    const val SCHEDULE_TYPE_COURSE = "course"
    const val SCHEDULE_TYPE_EVENT = "event"

    const val EXTRA_COURSE_INDEX = "course_index"
    const val EXTRA_TITLE = "extra_title"
    const val EXTRA_CONTENT = "extra_content"
    const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
    const val EXTRA_WINDOW_START_AT = "extra_window_start_at"
    const val EXTRA_WINDOW_END_AT = "extra_window_end_at"

    private const val RESTORE_CODE_OFFSET = 10000
    private const val BASE_CODE_REMINDER = 30000
    private const val DIAGNOSTIC_REQUEST_CODE = 90001
    private const val MUTE_DIAG_TAG = "MuteDiag"
    private const val DIAGNOSTIC_WINDOW_MILLIS = 5 * 60 * 1000L

    data class AlarmItem(
        val index: Int,
        val silentAtMillis: Long?,
        val restoreAtMillis: Long?,
        val reminderAtMillis: Long?,
        val title: String?,
        val content: String?,
        val notificationId: Int? = null,
        val reminderAction: String = ACTION_REMIND_CLASS,
        val scheduleType: String = SCHEDULE_TYPE_COURSE,
        val courseName: String? = null,
        val location: String? = null,
        val windowStartAtMillis: Long? = null,
        val windowEndAtMillis: Long? = null,
    )

    fun scheduleAll(
        context: Context,
        items: List<AlarmItem>,
    ) {
        reconcileMuteState(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val storedItems = NativeStateStore.loadAlarmItems(context)
        val mutedIndexes =
            storedItems
                .filter { item -> NativeStateStore.wasMutedByApp(context, item.index) }
                .mapTo(mutableSetOf()) { item -> item.index }
        val retainedRestoreItems =
            NativeMuteStatePolicy.retainedRestoreWork(
                storedItems = storedItems,
                mutedIndexes = mutedIndexes,
                now = now,
            )
        cancelScheduledIntents(context, alarmManager)
        val futureItems =
            NativeMuteStatePolicy.mergeRetainedRestoreWork(
                futureItems = items.filter { item -> item.hasFutureWork(now) },
                retainedItems = retainedRestoreItems,
            )
        NativeStateStore.saveAlarmItems(context, futureItems)
        futureItems.forEach { item ->
            scheduleClass(
                context = context,
                item = item,
                now = now,
            )
        }
        muteLog("scheduleAll complete input=${items.size} future=${futureItems.size}")
    }

    fun scheduleClass(
        context: Context,
        item: AlarmItem,
        now: Long = System.currentTimeMillis(),
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val index = item.index
        val canScheduleExact = canScheduleExactAlarms(context)
        val canChangeRingerMode = canChangeRingerMode(context)

        item.silentAtMillis?.let { silentAtMillis ->
            if (silentAtMillis <= now) {
                muteLog("scheduleClass skip past silent index=$index at=$silentAtMillis")
                return@let
            }
            if (
                NativeMuteStatePolicy.shouldScheduleManualMuteFallback(
                    silentAtMillis = silentAtMillis,
                    now = now,
                    canScheduleExact = canScheduleExact,
                    canChangeRingerMode = canChangeRingerMode,
                )
            ) {
                scheduleManualMuteFallback(
                    context = context,
                    item = item,
                    triggerAtMillis = silentAtMillis,
                    canScheduleExact = canScheduleExact,
                )
                return@let
            }
            if (!canChangeRingerMode) {
                muteLog(
                    "scheduleClass skip silent index=$index " +
                        "exact=$canScheduleExact dnd=$canChangeRingerMode",
                )
                return@let
            }
            val silentIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_SILENT
                putExtra(EXTRA_COURSE_INDEX, index)
                putWindowExtras(item)
            }
            val silentPendingIntent = PendingIntent.getBroadcast(
                context,
                requestCodeFor(ACTION_SILENT, index),
                silentIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setAlarmClockSafely(
                alarmManager = alarmManager,
                triggerAtMillis = silentAtMillis,
                pendingIntent = silentPendingIntent,
                label = "silent:$index",
            ) || setExactAllowWhileIdleSafely(
                alarmManager = alarmManager,
                triggerAtMillis = silentAtMillis,
                pendingIntent = silentPendingIntent,
                label = "silent:$index",
            )
        }

        item.restoreAtMillis?.let { restoreAtMillis ->
            if (restoreAtMillis <= now) {
                muteLog("scheduleClass skip past restore index=$index at=$restoreAtMillis")
                return@let
            }
            val restoreIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_RESTORE
                putExtra(EXTRA_COURSE_INDEX, index)
                putWindowExtras(item)
            }
            val restorePendingIntent = PendingIntent.getBroadcast(
                context,
                requestCodeFor(ACTION_RESTORE, index),
                restoreIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (!canChangeRingerMode) {
                muteLog("scheduleClass skip restore without DND permission index=$index")
                return@let
            }
            val scheduled =
                setAlarmClockSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = restoreAtMillis,
                    pendingIntent = restorePendingIntent,
                    label = "restore:$index",
                ) || setExactAllowWhileIdleSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = restoreAtMillis,
                    pendingIntent = restorePendingIntent,
                    label = "restore:$index",
                )
            if (!scheduled) {
                setInexactAllowWhileIdleSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = restoreAtMillis,
                    pendingIntent = restorePendingIntent,
                    label = "restore:$index",
                )
            }
        }

        item.reminderAtMillis?.let { reminderAt ->
            if (reminderAt <= now) {
                muteLog("scheduleClass skip past reminder index=$index at=$reminderAt")
                return@let
            }
            val reminderIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = item.reminderAction
                putExtra(EXTRA_TITLE, item.title ?: "提醒")
                putExtra(EXTRA_CONTENT, item.content ?: "时间到了")
                putExtra(EXTRA_COURSE_INDEX, index)
                putExtra(EXTRA_NOTIFICATION_ID, item.notificationId ?: index)
            }
            val reminderPendingIntent = PendingIntent.getBroadcast(
                context,
                requestCodeFor(item.reminderAction, index),
                reminderIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val scheduled =
                setAlarmClockSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = reminderAt,
                    pendingIntent = reminderPendingIntent,
                    label = "reminder:$index",
                ) || setExactAllowWhileIdleSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = reminderAt,
                    pendingIntent = reminderPendingIntent,
                    label = "reminder:$index",
                )
            if (!scheduled) {
                setInexactAllowWhileIdleSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = reminderAt,
                    pendingIntent = reminderPendingIntent,
                    label = "reminder:$index",
                )
            }
        }
    }

    fun cancelAll(context: Context) {
        reconcileMuteState(context, restoreActiveAppMute = true)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelScheduledIntents(context, alarmManager)
        NativeStateStore.clearAlarmItems(context)
    }

    fun rescheduleStored(context: Context) {
        val now = System.currentTimeMillis()
        val storedTimeZoneId = NativeStateStore.getAlarmItemsTimeZoneId(context)
        val currentTimeZoneId = TimeZone.getDefault().id
        val plan =
            NativeAlarmTimePolicy.prepareReschedule(
                alarmItems = NativeStateStore.loadAlarmItems(context),
                todayCourseItems = NativeStateStore.loadTodayCourses(context),
                sourceTimeZoneId = storedTimeZoneId,
                targetTimeZoneId = currentTimeZoneId,
                now = now,
            )
        reconcileMuteState(context, items = plan.reconciliationItems)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelScheduledIntents(context, alarmManager)
        NativeStateStore.saveAlarmItems(context, plan.futureItems)
        NativeStateStore.saveTodayCourses(context, plan.todayCourseItems)
        plan.futureItems.forEach { item -> scheduleClass(context, item, now) }
        muteLog("rescheduleStored complete future=${plan.futureItems.size}")
    }

    fun scheduleOneMinuteMuteTest(context: Context): DiagnosticScheduleResult {
        return scheduleDiagnosticMuteWindow(
            context = context,
            silentDelayMillis = 60_000L,
            restoreDelayMillis = 120_000L,
        )
    }

    fun scheduleDiagnosticMuteWindow(
        context: Context,
        silentDelayMillis: Long,
        restoreDelayMillis: Long,
    ): DiagnosticScheduleResult {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelDiagnosticMuteWindow(context, alarmManager)

        val now = System.currentTimeMillis()
        val silentAtMillis = now + silentDelayMillis
        val restoreAtMillis = now + restoreDelayMillis
        muteLog(
            "scheduleDiagnosticMuteWindow start silentAtMillis=$silentAtMillis " +
                "restoreAtMillis=$restoreAtMillis " +
                "silentDelayMillis=$silentDelayMillis restoreDelayMillis=$restoreDelayMillis",
        )
        val canScheduleExact = canScheduleExactAlarms(context)
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_SILENT
            putExtra(EXTRA_COURSE_INDEX, DIAGNOSTIC_REQUEST_CODE)
            putExtra(EXTRA_WINDOW_START_AT, silentAtMillis)
            putExtra(EXTRA_WINDOW_END_AT, restoreAtMillis + DIAGNOSTIC_WINDOW_MILLIS)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeFor(ACTION_SILENT, DIAGNOSTIC_REQUEST_CODE),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val silentScheduled = if (canScheduleExact) {
            setAlarmClockSafely(
                alarmManager = alarmManager,
                triggerAtMillis = silentAtMillis,
                pendingIntent = pendingIntent,
                label = "diagnostic-silent",
            ) || setExactAllowWhileIdleSafely(
                alarmManager = alarmManager,
                triggerAtMillis = silentAtMillis,
                pendingIntent = pendingIntent,
                label = "diagnostic-silent",
            )
        } else {
            val scheduled =
                setAlarmClockSafely(
                    alarmManager = alarmManager,
                    triggerAtMillis = silentAtMillis,
                    pendingIntent = pendingIntent,
                    label = "diagnostic-silent",
                )
            muteLog(
                "scheduleDiagnosticMuteWindow silent alarm exact missing " +
                    "alarmClockScheduled=$scheduled",
            )
            scheduled
        }
        muteLog(
            "scheduleDiagnosticMuteWindow silent alarm at=$silentAtMillis " +
                "scheduled=$silentScheduled",
        )
        if (!silentScheduled) {
            return NativeDiagnosticSchedulePolicy.result(
                silentScheduled = false,
                restoreScheduled = false,
            )
        }

        val restoreIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_RESTORE
            putExtra(EXTRA_COURSE_INDEX, DIAGNOSTIC_REQUEST_CODE)
            putExtra(EXTRA_WINDOW_START_AT, silentAtMillis)
            putExtra(EXTRA_WINDOW_END_AT, restoreAtMillis)
        }
        val restorePendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeFor(ACTION_RESTORE, DIAGNOSTIC_REQUEST_CODE),
            restoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val restoreScheduled =
            setAlarmClockSafely(
                alarmManager = alarmManager,
                triggerAtMillis = restoreAtMillis,
                pendingIntent = restorePendingIntent,
                label = "diagnostic-restore",
            ) || setExactAllowWhileIdleSafely(
                alarmManager = alarmManager,
                triggerAtMillis = restoreAtMillis,
                pendingIntent = restorePendingIntent,
                label = "diagnostic-restore",
            ) ||
            setInexactAllowWhileIdleSafely(
                alarmManager = alarmManager,
                triggerAtMillis = restoreAtMillis,
                pendingIntent = restorePendingIntent,
                label = "diagnostic-restore",
            )
        muteLog(
            "scheduleDiagnosticMuteWindow restore alarm at=$restoreAtMillis " +
                "scheduled=$restoreScheduled",
        )
        return NativeDiagnosticSchedulePolicy.result(
            silentScheduled = silentScheduled,
            restoreScheduled = restoreScheduled,
        )
    }

    fun cancelDiagnosticMuteWindow(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelDiagnosticMuteWindow(context, alarmManager)
    }

    private fun cancelByAction(
        context: Context,
        alarmManager: AlarmManager,
        action: String,
        requestCode: Int,
        index: Int,
    ) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_COURSE_INDEX, index)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun cancelScheduledIntents(
        context: Context,
        alarmManager: AlarmManager,
    ) {
        val storedItems = NativeStateStore.loadAlarmItems(context)
        storedItems.forEach { item ->
            val index = item.index
            cancelByAction(
                context,
                alarmManager,
                ACTION_SILENT,
                requestCodeFor(ACTION_SILENT, index),
                index,
            )
            cancelByAction(
                context,
                alarmManager,
                ACTION_RESTORE,
                requestCodeFor(ACTION_RESTORE, index),
                index,
            )
            cancelByAction(
                context,
                alarmManager,
                ACTION_REMIND_CLASS,
                requestCodeFor(ACTION_REMIND_CLASS, index),
                index,
            )
            cancelByAction(
                context,
                alarmManager,
                ACTION_REMIND_SCHEDULE,
                requestCodeFor(ACTION_REMIND_SCHEDULE, index),
                index,
            )
            cancelLegacyCodes(context, alarmManager, index)
        }

        val lastCount = NativeStateStore.getLastScheduledCount(context)
        for (index in 0 until lastCount) {
            cancelLegacyCodes(context, alarmManager, index)
        }

        cancelDiagnosticMuteWindow(context, alarmManager)
    }

    private fun cancelDiagnosticMuteWindow(
        context: Context,
        alarmManager: AlarmManager,
    ) {
        muteLog("cancelDiagnosticMuteWindow start")
        cancelByAction(
            context = context,
            alarmManager = alarmManager,
            action = ACTION_SILENT,
            requestCode = requestCodeFor(ACTION_SILENT, DIAGNOSTIC_REQUEST_CODE),
            index = DIAGNOSTIC_REQUEST_CODE,
        )
        cancelByAction(
            context = context,
            alarmManager = alarmManager,
            action = ACTION_RESTORE,
            requestCode = requestCodeFor(ACTION_RESTORE, DIAGNOSTIC_REQUEST_CODE),
            index = DIAGNOSTIC_REQUEST_CODE,
        )
        cancelLegacyCodes(context, alarmManager, DIAGNOSTIC_REQUEST_CODE)
        muteLog("cancelDiagnosticMuteWindow complete")
    }

    fun reconcileMuteState(
        context: Context,
        restoreActiveAppMute: Boolean = false,
        items: List<AlarmItem> = NativeStateStore.loadAlarmItems(context),
    ) {
        val now = System.currentTimeMillis()
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val canChangeRingerMode = canChangeRingerMode(context)
        items.forEach { item ->
            if (!NativeStateStore.wasMutedByApp(context, item.index)) {
                return@forEach
            }
            val windowEnd = item.windowEndAtMillis ?: item.restoreAtMillis
            val shouldRestore =
                restoreActiveAppMute || (windowEnd != null && windowEnd <= now)
            if (!shouldRestore) {
                return@forEach
            }

            val currentMode = audioManager.ringerMode
            val appAppliedMode =
                NativeStateStore.appliedRingerMode(context, item.index)
                    ?: AudioManager.RINGER_MODE_SILENT
            if (
                NativeMuteStatePolicy.shouldRestoreOwnedMute(
                    mutedByApp = true,
                    currentRingerMode = currentMode,
                    appAppliedRingerMode = appAppliedMode,
                )
            ) {
                if (!canChangeRingerMode) {
                    muteLog("reconcileMuteState cannot restore without DND index=${item.index}")
                    return@forEach
                }
                val restoreMode =
                    NativeStateStore.originalRingerMode(context, item.index)
                        ?: AudioManager.RINGER_MODE_NORMAL
                val restored = runCatching {
                    audioManager.ringerMode = restoreMode
                    NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
                    muteLog(
                        "reconcileMuteState restored index=${item.index} " +
                            "restoreMode=$restoreMode active=$restoreActiveAppMute",
                    )
                }.onFailure { error ->
                    muteLog(
                        "reconcileMuteState restore failed index=${item.index} " +
                            "error=${error.message}",
                    )
                }.isSuccess
                if (!restored) {
                    return@forEach
                }
            } else {
                muteLog(
                    "reconcileMuteState clearing index=${item.index} " +
                        "currentMode=$currentMode active=$restoreActiveAppMute",
                )
            }
            NativeStateStore.clearMutedByApp(context, item.index)
        }
    }

    private fun Intent.putWindowExtras(item: AlarmItem) {
        item.windowStartAtMillis?.let { putExtra(EXTRA_WINDOW_START_AT, it) }
        item.windowEndAtMillis?.let { putExtra(EXTRA_WINDOW_END_AT, it) }
    }

    private fun scheduleManualMuteFallback(
        context: Context,
        item: AlarmItem,
        triggerAtMillis: Long,
        canScheduleExact: Boolean,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val index = item.index
        val reminderIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_REMIND_CLASS
            putExtra(EXTRA_TITLE, "上课提醒: 请手动静音")
            putExtra(
                EXTRA_CONTENT,
                "${item.courseName ?: "课程"} 即将开始，当前设备权限不足，无法自动静音。",
            )
            putExtra(EXTRA_COURSE_INDEX, index)
            putExtra(EXTRA_NOTIFICATION_ID, item.notificationId ?: index)
        }
        val reminderPendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeFor(ACTION_REMIND_CLASS, index),
            reminderIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val scheduled =
            canScheduleExact &&
                (
                    setAlarmClockSafely(
                        alarmManager = alarmManager,
                        triggerAtMillis = triggerAtMillis,
                        pendingIntent = reminderPendingIntent,
                        label = "manual-mute:$index",
                    ) || setExactAllowWhileIdleSafely(
                        alarmManager = alarmManager,
                        triggerAtMillis = triggerAtMillis,
                        pendingIntent = reminderPendingIntent,
                        label = "manual-mute:$index",
                    )
                )
        if (!scheduled) {
            setInexactAllowWhileIdleSafely(
                alarmManager = alarmManager,
                triggerAtMillis = triggerAtMillis,
                pendingIntent = reminderPendingIntent,
                label = "manual-mute:$index",
            )
        }
        muteLog(
            "scheduleManualMuteFallback index=$index at=$triggerAtMillis exact=$canScheduleExact",
        )
    }

    private fun AlarmItem.hasFutureWork(now: Long): Boolean {
        return (silentAtMillis ?: Long.MIN_VALUE) > now ||
            (restoreAtMillis ?: Long.MIN_VALUE) > now ||
            (reminderAtMillis ?: Long.MIN_VALUE) > now ||
            (windowEndAtMillis ?: Long.MIN_VALUE) > now
    }

    private fun cancelLegacyCodes(
        context: Context,
        alarmManager: AlarmManager,
        index: Int,
    ) {
        cancelByAction(context, alarmManager, ACTION_SILENT, index, index)
        cancelByAction(context, alarmManager, ACTION_RESTORE, index + RESTORE_CODE_OFFSET, index)
        cancelByAction(context, alarmManager, ACTION_REMIND_CLASS, BASE_CODE_REMINDER + index, index)
        cancelByAction(context, alarmManager, ACTION_REMIND_SCHEDULE, BASE_CODE_REMINDER + index, index)
    }

    private fun requestCodeFor(
        action: String,
        index: Int,
    ): Int {
        return ("$action|$index".hashCode() and 0x7fffffff)
    }

    private fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.USE_EXACT_ALARM) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun canChangeRingerMode(context: Context): Boolean {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notificationManager.isNotificationPolicyAccessGranted
    }

    private fun setAlarmClockSafely(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
        label: String,
    ): Boolean {
        return try {
            muteLog("setAlarmClock label=$label triggerAtMillis=$triggerAtMillis")
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, null),
                pendingIntent,
            )
            true
        } catch (e: SecurityException) {
            muteLog("setAlarmClock security failure label=$label error=${e.message}")
            false
        } catch (e: RuntimeException) {
            muteLog("setAlarmClock failure label=$label error=${e.message}")
            false
        }
    }

    private fun setExactAllowWhileIdleSafely(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
        label: String,
    ): Boolean {
        return try {
            muteLog("setExactAllowWhileIdle label=$label triggerAtMillis=$triggerAtMillis")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
            true
        } catch (e: SecurityException) {
            muteLog("setExactAllowWhileIdle security failure label=$label error=${e.message}")
            false
        } catch (e: RuntimeException) {
            muteLog("setExactAllowWhileIdle failure label=$label error=${e.message}")
            false
        }
    }

    private fun setInexactAllowWhileIdleSafely(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
        label: String,
    ): Boolean {
        return try {
            muteLog("setInexactAllowWhileIdle label=$label triggerAtMillis=$triggerAtMillis")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
            true
        } catch (e: RuntimeException) {
            muteLog("setInexactAllowWhileIdle failure label=$label error=${e.message}")
            false
        }
    }

    private fun muteLog(message: String) {
        Log.d(MUTE_DIAG_TAG, "${System.currentTimeMillis()} $message")
    }
}

