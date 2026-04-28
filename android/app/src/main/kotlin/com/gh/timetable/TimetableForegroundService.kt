package com.gh.timetable

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import java.util.Date
import java.util.Locale

class TimetableForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val clockFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val updateRunnable =
        object : Runnable {
            override fun run() {
                updateNotification()
                handler.postDelayed(this, UPDATE_INTERVAL_MILLIS)
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
            stopUpdater()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        if (!NativeStateStore.isForegroundServiceEnabled(this) && action != ACTION_START) {
            stopSelf()
            return START_NOT_STICKY
        }

        NativeStateStore.setForegroundServiceEnabled(this, true)
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

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val now = System.currentTimeMillis()
        val todayCourses = NativeStateStore.loadTodayCourses(this).sortedBy { it.startAtMillis }
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
                "上课静音前台服务",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "用于持续刷新当前课程状态"
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

        const val ACTION_START = "com.timetable.action.START_FOREGROUND_SERVICE"
        const val ACTION_STOP = "com.timetable.action.STOP_FOREGROUND_SERVICE"
        const val ACTION_REFRESH = "com.timetable.action.REFRESH_FOREGROUND_SERVICE"

        fun setEnabled(
            context: Context,
            enabled: Boolean,
        ) {
            if (enabled) {
                start(context, ACTION_START)
            } else {
                NativeStateStore.setForegroundServiceEnabled(context, false)
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
            start(context, ACTION_REFRESH)
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
    }
}
