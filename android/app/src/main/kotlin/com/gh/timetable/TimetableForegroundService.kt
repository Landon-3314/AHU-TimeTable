package com.gh.timetable

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class TimetableForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val clockFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val updateRunnable =
        object : Runnable {
            override fun run() {
                if (updateNotification()) {
                    handler.postDelayed(this, UPDATE_INTERVAL_MILLIS)
                }
            }
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        val action = intent?.action ?: ACTION_START
        if (action == ACTION_STOP) {
            NativeStateStore.setForegroundServiceEnabled(this, false)
            cancelVisibilityAlarms(this)
            stopUpdater()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        if (action == ACTION_HIDE) {
            scheduleVisibilityAlarms(this)
            hideForegroundNotification()
            return START_NOT_STICKY
        }

        if (!NativeStateStore.isForegroundServiceEnabled(this) && action != ACTION_START) {
            stopSelf()
            return START_NOT_STICKY
        }

        NativeStateStore.setForegroundServiceEnabled(this, true)
        scheduleVisibilityAlarms(this)
        if (!isWithinDisplayWindow(this)) {
            hideForegroundNotification()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification())
        startUpdater()
        return START_STICKY
    }

    override fun onDestroy() {
        stopUpdater()
        super.onDestroy()
    }

    private fun startUpdater() {
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
    }

    private fun stopUpdater() {
        handler.removeCallbacks(updateRunnable)
    }

    private fun updateNotification(): Boolean {
        if (!isWithinDisplayWindow(this)) {
            hideForegroundNotification()
            return false
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
        return true
    }

    private fun hideForegroundNotification() {
        stopUpdater()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val now = System.currentTimeMillis()
        val todayCourses = loadCoursesForLocalDay(now)
        val lastCourseEndAt = todayCourses.maxOfOrNull { it.endAtMillis }
        val current =
            todayCourses.firstOrNull { item ->
                now in item.startAtMillis until item.endAtMillis
            }
        val next = todayCourses.firstOrNull { item -> now < item.startAtMillis }

        val (title, content) =
            when {
                todayCourses.isEmpty() || lastCourseEndAt == null || now > lastCourseEndAt -> {
                    "今日已无课程" to "好好休息一下吧！"
                }

                current != null -> {
                    val endText = formatTime(current.endAtMillis)
                    "当前课程: ${current.courseName}" to
                        "${formatLocation(current.location)} | $endText 下课"
                }

                next != null -> {
                    val startText = formatTime(next.startAtMillis)
                    "下一节课: ${next.courseName}" to
                        "${formatLocation(next.location)} | $startText 上课"
                }

                else -> "今日已无课程" to "好好休息一下吧！"
            }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_bg_service_small)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(buildContentIntent())
            .build()
    }

    private fun loadCoursesForLocalDay(nowMillis: Long): List<NativeStateStore.TodayCourseItem> {
        val dayStart = startOfLocalDayMillis(nowMillis)
        val dayEnd = startOfNextLocalDayMillis(nowMillis)
        return loadCourseItems(this, nowMillis)
            .filter { item -> item.endAtMillis > dayStart && item.startAtMillis < dayEnd }
            .sortedBy { it.startAtMillis }
    }

    private fun buildContentIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "课前提醒持久显示",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "用于在上课前和上课期间持续显示当前课程状态"
                setShowBadge(false)
            }
        manager.createNotificationChannel(channel)
    }

    private fun formatLocation(location: String?): String {
        val trimmed = location?.trim().orEmpty()
        return if (trimmed.isEmpty()) "地点待定" else trimmed
    }

    private fun formatTime(millis: Long): String {
        return clockFormat.format(Date(millis))
    }

    companion object {
        private const val CHANNEL_ID = "class_mute_native_foreground"
        private const val NOTIFICATION_ID = 888
        private const val UPDATE_INTERVAL_MILLIS = 60_000L
        private const val DISPLAY_LEAD_MILLIS = 10 * 60 * 1000L
        private const val DISPLAY_TAIL_MILLIS = 0L
        private const val SHOW_REQUEST_CODE = 88007
        private const val HIDE_REQUEST_CODE = 88022

        const val ACTION_START = "com.timetable.action.START_FOREGROUND_SERVICE"
        const val ACTION_STOP = "com.timetable.action.STOP_FOREGROUND_SERVICE"
        const val ACTION_REFRESH = "com.timetable.action.REFRESH_FOREGROUND_SERVICE"
        const val ACTION_SHOW = "com.timetable.action.SHOW_FOREGROUND_SERVICE"
        const val ACTION_HIDE = "com.timetable.action.HIDE_FOREGROUND_SERVICE"

        fun setEnabled(
            context: Context,
            enabled: Boolean,
        ) {
            if (enabled) {
                NativeStateStore.setForegroundServiceEnabled(context, true)
                scheduleVisibilityAlarms(context)
                if (isWithinDisplayWindow(context)) {
                    start(context, ACTION_START)
                } else {
                    cancelForegroundNotification(context)
                }
            } else {
                NativeStateStore.setForegroundServiceEnabled(context, false)
                cancelVisibilityAlarms(context)
                cancelForegroundNotification(context)
                runCatching {
                    context.startService(
                        Intent(context, TimetableForegroundService::class.java).apply {
                            action = ACTION_STOP
                        },
                    )
                }
            }
        }

        fun requestRefresh(context: Context) {
            if (!NativeStateStore.isForegroundServiceEnabled(context)) {
                return
            }
            scheduleVisibilityAlarms(context)
            if (isWithinDisplayWindow(context)) {
                start(context, ACTION_REFRESH)
            } else {
                cancelForegroundNotification(context)
                runCatching {
                    context.startService(
                        Intent(context, TimetableForegroundService::class.java).apply {
                            action = ACTION_HIDE
                        },
                    )
                }
            }
        }

        fun handleVisibilityWindowAlarm(
            context: Context,
            action: String,
        ) {
            if (!NativeStateStore.isForegroundServiceEnabled(context)) {
                cancelVisibilityAlarms(context)
                cancelForegroundNotification(context)
                return
            }

            scheduleVisibilityAlarms(context)
            when (action) {
                ACTION_SHOW -> {
                    if (isWithinDisplayWindow(context)) {
                        start(context, ACTION_REFRESH)
                    }
                }

                ACTION_HIDE -> {
                    cancelForegroundNotification(context)
                    runCatching {
                        context.startService(
                            Intent(context, TimetableForegroundService::class.java).apply {
                                this.action = ACTION_HIDE
                            },
                        )
                    }
                }
            }
        }

        private fun start(
            context: Context,
            action: String,
        ) {
            NativeStateStore.setForegroundServiceEnabled(context, true)
            ContextCompat.startForegroundService(
                context,
                Intent(context, TimetableForegroundService::class.java).apply {
                    this.action = action
                },
            )
        }

        private data class DisplayWindow(
            val startAtMillis: Long,
            val endAtMillis: Long,
        )

        private fun isWithinDisplayWindow(
            context: Context,
            nowMillis: Long = System.currentTimeMillis(),
        ): Boolean {
            return currentDisplayWindow(context, nowMillis) != null
        }

        private fun scheduleVisibilityAlarms(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val showIntent = visibilityPendingIntent(context, ACTION_SHOW, SHOW_REQUEST_CODE)
            val hideIntent = visibilityPendingIntent(context, ACTION_HIDE, HIDE_REQUEST_CODE)
            alarmManager.cancel(showIntent)
            alarmManager.cancel(hideIntent)

            val now = System.currentTimeMillis()
            nextDisplayStartMillis(context, now)?.let { triggerAtMillis ->
                scheduleVisibilityAlarm(
                    alarmManager = alarmManager,
                    pendingIntent = showIntent,
                    triggerAtMillis = triggerAtMillis,
                )
            }
            currentDisplayWindow(context, now)?.let { window ->
                scheduleVisibilityAlarm(
                    alarmManager = alarmManager,
                    pendingIntent = hideIntent,
                    triggerAtMillis = window.endAtMillis,
                )
            }
        }

        private fun cancelVisibilityAlarms(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(visibilityPendingIntent(context, ACTION_SHOW, SHOW_REQUEST_CODE))
            alarmManager.cancel(visibilityPendingIntent(context, ACTION_HIDE, HIDE_REQUEST_CODE))
        }

        private fun scheduleVisibilityAlarm(
            alarmManager: AlarmManager,
            pendingIntent: PendingIntent,
            triggerAtMillis: Long,
        ) {
            alarmManager.cancel(pendingIntent)
            try {
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
            } catch (_: SecurityException) {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        }

        private fun visibilityPendingIntent(
            context: Context,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, AlarmReceiver::class.java).apply {
                    this.action = action
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun currentDisplayWindow(
            context: Context,
            nowMillis: Long,
        ): DisplayWindow? {
            val dayStart = startOfLocalDayMillis(nowMillis)
            val dayEnd = startOfNextLocalDayMillis(nowMillis)
            val courses =
                loadCourseItems(context, nowMillis)
                    .filter { item -> item.endAtMillis > dayStart && item.startAtMillis < dayEnd }

            if (courses.isEmpty()) {
                return null
            }

            val startAtMillis = courses.minOf { it.startAtMillis } - DISPLAY_LEAD_MILLIS
            val endAtMillis = courses.maxOf { it.endAtMillis } + DISPLAY_TAIL_MILLIS
            return if (nowMillis in startAtMillis until endAtMillis) {
                DisplayWindow(startAtMillis, endAtMillis)
            } else {
                null
            }
        }

        private fun nextDisplayStartMillis(
            context: Context,
            nowMillis: Long,
        ): Long? {
            return displayWindows(context, nowMillis)
                .asSequence()
                .map { window -> window.startAtMillis }
                .filter { startAtMillis -> startAtMillis > nowMillis }
                .minOrNull()
        }

        private fun displayWindows(
            context: Context,
            nowMillis: Long,
        ): List<DisplayWindow> {
            return loadCourseItems(context, nowMillis)
                .groupBy { item -> startOfLocalDayMillis(item.startAtMillis) }
                .values
                .mapNotNull { courses ->
                    val startAtMillis = courses.minOfOrNull { it.startAtMillis }
                        ?: return@mapNotNull null
                    val endAtMillis = courses.maxOfOrNull { it.endAtMillis }
                        ?: return@mapNotNull null
                    DisplayWindow(
                        startAtMillis = startAtMillis - DISPLAY_LEAD_MILLIS,
                        endAtMillis = endAtMillis + DISPLAY_TAIL_MILLIS,
                    )
                }
                .filter { window -> window.endAtMillis > nowMillis }
                .sortedBy { window -> window.startAtMillis }
        }

        private fun loadCourseItems(
            context: Context,
            nowMillis: Long,
        ): List<NativeStateStore.TodayCourseItem> {
            val fromAlarmItems =
                NativeStateStore.loadAlarmItems(context)
                    .asSequence()
                    .filter { item -> item.scheduleType == NativeAlarmScheduler.SCHEDULE_TYPE_COURSE }
                    .mapNotNull { item ->
                        val startAtMillis = item.windowStartAtMillis ?: return@mapNotNull null
                        val endAtMillis = item.windowEndAtMillis ?: return@mapNotNull null
                        NativeStateStore.TodayCourseItem(
                            courseName = item.courseName ?: "未命名课程",
                            location = item.location,
                            startAtMillis = startAtMillis,
                            endAtMillis = endAtMillis,
                        )
                    }

            val todayStart = startOfLocalDayMillis(nowMillis)
            val tomorrowStart = startOfNextLocalDayMillis(nowMillis)
            val fromLegacyTodayCourses =
                NativeStateStore.loadTodayCourses(context)
                    .asSequence()
                    .filter { item -> item.endAtMillis > todayStart && item.startAtMillis < tomorrowStart }

            return (fromAlarmItems + fromLegacyTodayCourses)
                .distinctBy { item ->
                    listOf(
                        item.courseName,
                        item.location.orEmpty(),
                        item.startAtMillis,
                        item.endAtMillis,
                    ).joinToString("|")
                }
                .toList()
        }

        private fun startOfLocalDayMillis(nowMillis: Long): Long {
            return Calendar.getInstance().run {
                timeInMillis = nowMillis
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                timeInMillis
            }
        }

        private fun startOfNextLocalDayMillis(nowMillis: Long): Long {
            return Calendar.getInstance().run {
                timeInMillis = startOfLocalDayMillis(nowMillis)
                add(Calendar.DAY_OF_YEAR, 1)
                timeInMillis
            }
        }

        private fun cancelForegroundNotification(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }
    }
}
