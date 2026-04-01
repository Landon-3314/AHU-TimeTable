package com.example.timetable

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
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
        private const val AUTO_MUTE_PREFS = "auto_mute_prefs"

        private const val REMINDER_CHANNEL_ID = "reminder_channel"
        private const val REMINDER_CHANNEL_NAME = "课程与日程提醒"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Timetable::NativeAlarmWakeLock",
        )
        wakeLock.acquire(5000L)

        try {
            when (intent.action) {
                NativeAlarmScheduler.ACTION_SILENT -> applySilent(context, intent)
                NativeAlarmScheduler.ACTION_RESTORE -> applyRestore(context, intent)
                NativeAlarmScheduler.ACTION_REMIND_CLASS,
                NativeAlarmScheduler.ACTION_REMIND_SCHEDULE,
                -> showReminderNotification(context, intent)

                else -> Log.w(TAG, "Unknown alarm action: ${intent.action}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "AlarmReceiver execution failed: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }

    private fun applySilent(context: Context, intent: Intent) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
        val index = intent.getIntExtra(NativeAlarmScheduler.EXTRA_COURSE_INDEX, -1)
        val key = "app_did_mute_$index"

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            prefs.edit().putBoolean(key, false).apply()
            Log.w(TAG, "Notification policy access missing, skip silent for index=$index")
            return
        }

        val currentMode = audioManager.ringerMode
        if (currentMode != AudioManager.RINGER_MODE_NORMAL) {
            prefs.edit().putBoolean(key, false).apply()
            Log.d(TAG, "Device already silent/vibrate, skip auto mute for index=$index")
            return
        }

        prefs.edit().putBoolean(key, true).apply()
        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        Log.d(TAG, "App auto-muted device for index=$index")
    }

    private fun applyRestore(context: Context, intent: Intent) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
        val index = intent.getIntExtra(NativeAlarmScheduler.EXTRA_COURSE_INDEX, -1)
        val key = "app_did_mute_$index"
        val wasMutedByApp = prefs.getBoolean(key, false)

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            prefs.edit().remove(key).apply()
            Log.w(TAG, "Notification policy access missing, skip restore for index=$index")
            return
        }

        if (wasMutedByApp) {
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            Log.d(TAG, "App restored normal mode for index=$index")
        } else {
            Log.d(TAG, "Skip restore because app did not mute index=$index")
        }

        prefs.edit().remove(key).apply()
    }

    private fun showReminderNotification(context: Context, intent: Intent) {
        ensureReminderChannel(context)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "POST_NOTIFICATIONS not granted, skip reminder notification")
                return
            }
        }

        val title =
            intent.getStringExtra(NativeAlarmScheduler.EXTRA_TITLE) ?: "提醒"
        val content =
            intent.getStringExtra(NativeAlarmScheduler.EXTRA_CONTENT) ?: "时间到了"

        val notification = NotificationCompat.Builder(context, REMINDER_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationId = (System.currentTimeMillis() and 0xFFFFFFF).toInt()
        NotificationManagerCompat.from(context).notify(notificationId, notification)
        Log.d(TAG, "Reminder notification sent: $title")
    }

    private fun ensureReminderChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            REMINDER_CHANNEL_ID,
            REMINDER_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "课程与日程提醒通知"
        }
        manager.createNotificationChannel(channel)
    }
}
