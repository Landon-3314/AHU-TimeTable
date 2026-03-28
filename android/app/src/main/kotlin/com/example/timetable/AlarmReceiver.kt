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
        private const val PREFS = "native_alarm_prefs"
        private const val SAVED_MUSIC_VOLUME_KEY = "saved_music_volume"
        private const val HAS_SAVED_VOLUME_KEY = "has_saved_volume"

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
                NativeAlarmScheduler.ACTION_SILENT -> applySilent(context)
                NativeAlarmScheduler.ACTION_RESTORE -> applyRestore(context)
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

    private fun applySilent(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        val currentMusic = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (currentMusic > 0) {
            prefs.edit()
                .putInt(SAVED_MUSIC_VOLUME_KEY, currentMusic)
                .putBoolean(HAS_SAVED_VOLUME_KEY, true)
                .apply()
        }

        if (notificationManager.isNotificationPolicyAccessGranted) {
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        }
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
        Log.d(TAG, "Applied silent mode via native alarm")
    }

    private fun applyRestore(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        if (notificationManager.isNotificationPolicyAccessGranted) {
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
        }

        val hasSaved = prefs.getBoolean(HAS_SAVED_VOLUME_KEY, false)
        val fallback = (audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC) * 0.4f)
            .toInt()
            .coerceAtLeast(1)
        val restoreVolume = if (hasSaved) {
            prefs.getInt(SAVED_MUSIC_VOLUME_KEY, fallback)
        } else {
            fallback
        }
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, restoreVolume, 0)

        prefs.edit()
            .remove(SAVED_MUSIC_VOLUME_KEY)
            .putBoolean(HAS_SAVED_VOLUME_KEY, false)
            .apply()

        Log.d(TAG, "Restored normal mode via native alarm")
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
