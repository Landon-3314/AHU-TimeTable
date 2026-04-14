package com.example.timetable

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

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

    private const val RESTORE_CODE_OFFSET = 10000
    private const val BASE_CODE_REMINDER = 30000
    private const val DIAGNOSTIC_REQUEST_CODE = 90001

    data class AlarmItem(
        val index: Int,
        val silentAtMillis: Long?,
        val restoreAtMillis: Long?,
        val reminderAtMillis: Long?,
        val title: String?,
        val content: String?,
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
        cancelAll(context)
        NativeStateStore.saveAlarmItems(context, items)
        items.forEach { item ->
            scheduleClass(
                context = context,
                item = item,
            )
        }
    }

    fun scheduleClass(
        context: Context,
        item: AlarmItem,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val index = item.index

        item.silentAtMillis?.let { silentAtMillis ->
            val silentIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_SILENT
                putExtra(EXTRA_COURSE_INDEX, index)
            }
            val silentPendingIntent = PendingIntent.getBroadcast(
                context,
                index,
                silentIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setAlarmClock(alarmManager, silentAtMillis, silentPendingIntent)
        }

        item.restoreAtMillis?.let { restoreAtMillis ->
            val restoreIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_RESTORE
                putExtra(EXTRA_COURSE_INDEX, index)
            }
            val restorePendingIntent = PendingIntent.getBroadcast(
                context,
                index + RESTORE_CODE_OFFSET,
                restoreIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setAlarmClock(alarmManager, restoreAtMillis, restorePendingIntent)
        }

        item.reminderAtMillis?.let { reminderAt ->
            val reminderIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = item.reminderAction
                putExtra(EXTRA_TITLE, item.title ?: "提醒")
                putExtra(EXTRA_CONTENT, item.content ?: "时间到了")
                putExtra(EXTRA_COURSE_INDEX, index)
            }
            val reminderPendingIntent = PendingIntent.getBroadcast(
                context,
                BASE_CODE_REMINDER + index,
                reminderIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setAlarmClock(alarmManager, reminderAt, reminderPendingIntent)
        }
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val lastCount = NativeStateStore.getLastScheduledCount(context)

        for (index in 0 until lastCount) {
            cancelByAction(context, alarmManager, ACTION_SILENT, index, index)
            cancelByAction(context, alarmManager, ACTION_RESTORE, index + RESTORE_CODE_OFFSET, index)
            cancelByAction(context, alarmManager, ACTION_REMIND_CLASS, BASE_CODE_REMINDER + index, index)
            cancelByAction(context, alarmManager, ACTION_REMIND_SCHEDULE, BASE_CODE_REMINDER + index, index)
        }

        cancelByAction(
            context = context,
            alarmManager = alarmManager,
            action = ACTION_SILENT,
            requestCode = DIAGNOSTIC_REQUEST_CODE,
            index = DIAGNOSTIC_REQUEST_CODE,
        )

        NativeStateStore.clearAlarmItems(context)
    }

    fun scheduleOneMinuteMuteTest(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = System.currentTimeMillis() + 60_000L
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_SILENT
            putExtra(EXTRA_COURSE_INDEX, DIAGNOSTIC_REQUEST_CODE)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            DIAGNOSTIC_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        setAlarmClock(alarmManager, triggerAtMillis, pendingIntent)
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

    private fun setAlarmClock(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
    ) {
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAtMillis, null),
            pendingIntent,
        )
    }
}

