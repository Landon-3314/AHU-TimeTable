package com.gh.timetable

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmReceiver"
        private const val MUTE_DIAG_TAG = "MuteDiag"
        private const val REMINDER_CHANNEL_ID = "timetable_reminders"
        private const val REMINDER_CHANNEL_NAME = "课程与日程提醒"
        private const val WAKE_LOCK_TAG = "AHUTimeTable:AlarmWakeLock"
        private const val SILENT_EARLY_GRACE_MILLIS = 60_000L
        private const val SILENT_LATE_GRACE_MILLIS = 5 * 60_000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG,
        )
        wakeLock.acquire(10_000L)

        try {
            val action = intent.action.orEmpty()
            muteLog("onReceive action=$action")
            when (action) {
                NativeAlarmScheduler.ACTION_SILENT -> applySilent(context, intent)
                NativeAlarmScheduler.ACTION_RESTORE -> applyRestore(context, intent)
                NativeAlarmScheduler.ACTION_REMIND_CLASS,
                NativeAlarmScheduler.ACTION_REMIND_SCHEDULE,
                -> showReminderNotification(context, intent)
                TimetableForegroundService.ACTION_SHOW,
                TimetableForegroundService.ACTION_HIDE,
                -> TimetableForegroundService.handleVisibilityWindowAlarm(context, action)

                else -> Log.w(TAG, "Unknown alarm action: $action")
            }
        } catch (e: Exception) {
            Log.e(TAG, "AlarmReceiver execution failed: ${e.message}", e)
        } finally {
            runCatching {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }
        }
    }

    private fun applySilent(context: Context, intent: Intent) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val index = intent.getIntExtra(NativeAlarmScheduler.EXTRA_COURSE_INDEX, -1)
        val windowStart = intent.optionalLong(NativeAlarmScheduler.EXTRA_WINDOW_START_AT)
        val windowEnd = intent.optionalLong(NativeAlarmScheduler.EXTRA_WINDOW_END_AT)
        val now = System.currentTimeMillis()
        NativeStateStore.recordAlarmAction(context, NativeAlarmScheduler.ACTION_SILENT, index)
        muteLog(
            "applySilent start index=$index " +
                "windowStart=$windowStart windowEnd=$windowEnd now=$now " +
                "policyAccess=${notificationManager.isNotificationPolicyAccessGranted} " +
                "currentMode=${audioManager.ringerMode}",
        )

        if (!isWithinSilentExecutionWindow(now, windowStart, windowEnd)) {
            NativeStateStore.setMutedByApp(context, index, false)
            NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
            muteLog("applySilent skipped: outside execution window index=$index")
            return
        }

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            NativeStateStore.setMutedByApp(context, index, false)
            NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
            muteLog("applySilent skipped: notification policy access missing index=$index")
            Log.w(TAG, "Notification policy access missing, skip silent for index=$index")
            return
        }

        val currentMode = audioManager.ringerMode
        if (currentMode != AudioManager.RINGER_MODE_NORMAL) {
            val existingAppMute = hasActiveAppMute(context, index, now)
            NativeStateStore.setMutedByApp(context, index, existingAppMute)
            NativeStateStore.recordRingerMode(context, currentMode)
            muteLog(
                "applySilent skipped: already non-normal index=$index " +
                    "currentMode=$currentMode existingAppMute=$existingAppMute",
            )
            Log.d(TAG, "Device already silent/vibrate, skip auto mute for index=$index")
            return
        }

        NativeStateStore.recordOriginalRingerMode(context, index, currentMode)
        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        NativeStateStore.setMutedByApp(context, index, true)
        NativeStateStore.recordAppliedRingerMode(context, index, audioManager.ringerMode)
        NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
        muteLog("applySilent success index=$index mode=${audioManager.ringerMode}")
        Log.d(TAG, "App auto-muted device for index=$index")
    }

    private fun applyRestore(context: Context, intent: Intent) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val index = intent.getIntExtra(NativeAlarmScheduler.EXTRA_COURSE_INDEX, -1)
        val now = System.currentTimeMillis()
        val wasMutedByApp = NativeStateStore.wasMutedByApp(context, index)
        NativeStateStore.recordAlarmAction(context, NativeAlarmScheduler.ACTION_RESTORE, index)
        muteLog(
            "applyRestore start index=$index wasMutedByApp=$wasMutedByApp " +
                "policyAccess=${notificationManager.isNotificationPolicyAccessGranted} " +
                "currentMode=${audioManager.ringerMode}",
        )

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
            muteLog("applyRestore skipped: notification policy access missing index=$index")
            Log.w(TAG, "Notification policy access missing, skip restore for index=$index")
            return
        }

        if (wasMutedByApp) {
            val currentMode = audioManager.ringerMode
            val appAppliedMode =
                NativeStateStore.appliedRingerMode(context, index)
                    ?: AudioManager.RINGER_MODE_SILENT
            if (
                NativeMuteStatePolicy.shouldRestoreOwnedMute(
                    mutedByApp = true,
                    currentRingerMode = currentMode,
                    appAppliedRingerMode = appAppliedMode,
                )
            ) {
                if (hasActiveAppMute(context, index, now)) {
                    muteLog("applyRestore skipped: another app mute window is active index=$index")
                    NativeStateStore.clearMutedByApp(context, index)
                    return
                }
                val restoreMode =
                    NativeStateStore.originalRingerMode(context, index)
                        ?: AudioManager.RINGER_MODE_NORMAL
                audioManager.ringerMode = restoreMode
                muteLog("applyRestore success index=$index restoreMode=$restoreMode")
                Log.d(TAG, "App restored ringer mode=$restoreMode for index=$index")
            } else {
                muteLog(
                    "applyRestore skipped: user changed mode index=$index currentMode=$currentMode",
                )
                Log.d(TAG, "Skip restore because user already changed mode for index=$index")
            }
        } else {
            muteLog("applyRestore skipped: app did not mute index=$index")
            Log.d(TAG, "Skip restore because app did not mute index=$index")
        }

        NativeStateStore.clearMutedByApp(context, index)
        NativeStateStore.recordRingerMode(context, audioManager.ringerMode)
    }

    private fun muteLog(message: String) {
        Log.d(MUTE_DIAG_TAG, "${System.currentTimeMillis()} $message")
    }

    private fun showReminderNotification(context: Context, intent: Intent) {
        ensureReminderChannel(context)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted =
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "POST_NOTIFICATIONS not granted, skip reminder notification")
                return
            }
        }

        val title = intent.getStringExtra(NativeAlarmScheduler.EXTRA_TITLE) ?: "提醒"
        val content = intent.getStringExtra(NativeAlarmScheduler.EXTRA_CONTENT) ?: "时间到了"
        val notificationId =
            intent.getIntExtra(
                NativeAlarmScheduler.EXTRA_NOTIFICATION_ID,
                (System.currentTimeMillis() and 0x0FFFFFFF).toInt(),
            )

        val notification =
            NotificationCompat.Builder(context, REMINDER_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(content)
                .setStyle(NotificationCompat.BigTextStyle().bigText(content))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(buildLaunchIntent(context))
                .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
        Log.d(TAG, "Reminder notification sent: $title")
    }

    private fun ensureReminderChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                REMINDER_CHANNEL_ID,
                REMINDER_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "课程与日程提醒通知"
            }
        manager.createNotificationChannel(channel)
    }

    private fun isWithinSilentExecutionWindow(
        now: Long,
        windowStart: Long?,
        windowEnd: Long?,
    ): Boolean {
        if (windowStart == null || windowEnd == null || windowEnd <= windowStart) {
            return false
        }
        val earliest = windowStart - SILENT_EARLY_GRACE_MILLIS
        val latest = minOf(windowStart + SILENT_LATE_GRACE_MILLIS, windowEnd)
        return now in earliest..latest
    }

    private fun hasActiveAppMute(
        context: Context,
        ignoredIndex: Int,
        now: Long,
    ): Boolean {
        return NativeStateStore.loadAlarmItems(context).any { item ->
            item.index != ignoredIndex &&
                NativeStateStore.wasMutedByApp(context, item.index) &&
                (item.windowEndAtMillis ?: item.restoreAtMillis ?: 0L) > now
        }
    }

    private fun buildLaunchIntent(context: Context): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun Intent.optionalLong(key: String): Long? {
        return if (hasExtra(key)) getLongExtra(key, 0L) else null
    }
}

