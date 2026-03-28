package com.example.timetable

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object NativeAlarmScheduler {
    const val ACTION_SILENT = "com.timetable.ACTION_SILENT"
    const val ACTION_RESTORE = "com.timetable.ACTION_RESTORE"
    const val ACTION_REMIND_CLASS = "com.timetable.ACTION_REMIND_CLASS"
    const val ACTION_REMIND_SCHEDULE = "com.timetable.ACTION_REMIND_SCHEDULE"

    const val EXTRA_TITLE = "extra_title"
    const val EXTRA_CONTENT = "extra_content"

    private const val PREFS = "native_alarm_prefs"
    private const val LAST_COUNT_KEY = "last_scheduled_count"

    private const val BASE_CODE_SILENT = 10000
    private const val BASE_CODE_RESTORE = 20000
    private const val BASE_CODE_REMINDER = 30000

    data class AlarmItem(
        val silentAtMillis: Long,
        val restoreAtMillis: Long,
        val reminderAtMillis: Long?,
        val title: String?,
        val content: String?,
        val reminderAction: String = ACTION_REMIND_CLASS,
    )

    fun scheduleAll(
        context: Context,
        items: List<AlarmItem>,
    ) {
        cancelAll(context)
        items.forEachIndexed { index, item ->
            scheduleClass(
                context = context,
                item = item,
                index = index,
            )
        }

        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(LAST_COUNT_KEY, items.size)
            .apply()
    }

    fun scheduleClass(
        context: Context,
        item: AlarmItem,
        index: Int,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val silentIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_SILENT
            putExtra("index", index)
        }
        val restoreIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_RESTORE
            putExtra("index", index)
        }

        val silentPendingIntent = PendingIntent.getBroadcast(
            context,
            BASE_CODE_SILENT + index,
            silentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val restorePendingIntent = PendingIntent.getBroadcast(
            context,
            BASE_CODE_RESTORE + index,
            restoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        setExactAlarm(alarmManager, item.silentAtMillis, silentPendingIntent)
        setExactAlarm(alarmManager, item.restoreAtMillis, restorePendingIntent)

        val reminderAt = item.reminderAtMillis
        if (reminderAt != null) {
            val reminderIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = item.reminderAction
                putExtra(EXTRA_TITLE, item.title ?: "提醒")
                putExtra(EXTRA_CONTENT, item.content ?: "时间到了")
                putExtra("index", index)
            }
            val reminderPendingIntent = PendingIntent.getBroadcast(
                context,
                BASE_CODE_REMINDER + index,
                reminderIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setExactAlarm(alarmManager, reminderAt, reminderPendingIntent)
        }
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val lastCount = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt(LAST_COUNT_KEY, 0)

        for (index in 0 until lastCount) {
            cancelByAction(context, alarmManager, ACTION_SILENT, BASE_CODE_SILENT + index, index)
            cancelByAction(context, alarmManager, ACTION_RESTORE, BASE_CODE_RESTORE + index, index)
            cancelByAction(context, alarmManager, ACTION_REMIND_CLASS, BASE_CODE_REMINDER + index, index)
            cancelByAction(context, alarmManager, ACTION_REMIND_SCHEDULE, BASE_CODE_REMINDER + index, index)
        }

        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(LAST_COUNT_KEY, 0)
            .apply()
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
            putExtra("index", index)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun setExactAlarm(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
    ) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
            return
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
            return
        }

        alarmManager.set(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )
    }
}
