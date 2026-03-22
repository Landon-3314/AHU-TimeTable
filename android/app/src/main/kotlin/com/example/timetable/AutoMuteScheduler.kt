package com.example.timetable

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

private const val AUTO_MUTE_PREFS = "auto_mute_prefs"
private const val AUTO_MUTE_TASKS_KEY = "scheduled_tasks"
private const val EXTRA_MODE = "mode"

data class AutoMuteTask(
    val id: Int,
    val timestamp: Long,
    val mode: String,
)

object AutoMuteScheduler {
    fun isNotificationPolicyGranted(context: Context): Boolean {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.isNotificationPolicyAccessGranted
    }

    fun openNotificationPolicySettings(context: Context) {
        val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun setMode(context: Context, mode: String) {
        if (!isNotificationPolicyGranted(context)) {
            return
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.ringerMode = when (mode) {
            "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
            else -> AudioManager.RINGER_MODE_NORMAL
        }
    }

    fun replaceTasks(context: Context, tasks: List<AutoMuteTask>) {
        cancelStoredTasks(context)
        scheduleTasks(context, tasks)
        saveTasks(context, tasks)
    }

    fun rescheduleStoredTasks(context: Context) {
        val tasks = loadTasks(context).filter { it.timestamp > System.currentTimeMillis() }
        if (tasks.isEmpty()) {
            clearStoredTasks(context)
            return
        }

        scheduleTasks(context, tasks)
        saveTasks(context, tasks)
    }

    private fun scheduleTasks(context: Context, tasks: List<AutoMuteTask>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        tasks.forEach { task ->
            if (task.timestamp <= System.currentTimeMillis()) {
                return@forEach
            }

            val pendingIntent = buildPendingIntent(context, task)
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        task.timestamp,
                        pendingIntent,
                    )
                }

                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        task.timestamp,
                        pendingIntent,
                    )
                }
            }
        }
    }

    private fun cancelStoredTasks(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        loadTasks(context).forEach { task ->
            alarmManager.cancel(buildPendingIntent(context, task))
        }
        clearStoredTasks(context)
    }

    private fun buildPendingIntent(context: Context, task: AutoMuteTask): PendingIntent {
        val intent = Intent(context, AutoMuteReceiver::class.java).apply {
            putExtra(EXTRA_MODE, task.mode)
        }

        return PendingIntent.getBroadcast(
            context,
            task.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun saveTasks(context: Context, tasks: List<AutoMuteTask>) {
        val array = JSONArray()
        tasks.forEach { task ->
            array.put(
                JSONObject().apply {
                    put("id", task.id)
                    put("timestamp", task.timestamp)
                    put("mode", task.mode)
                },
            )
        }

        context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(AUTO_MUTE_TASKS_KEY, array.toString())
            .apply()
    }

    private fun loadTasks(context: Context): List<AutoMuteTask> {
        val raw = context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
            .getString(AUTO_MUTE_TASKS_KEY, null)
            ?: return emptyList()

        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        AutoMuteTask(
                            id = item.getInt("id"),
                            timestamp = item.getLong("timestamp"),
                            mode = item.getString("mode"),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun clearStoredTasks(context: Context) {
        context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(AUTO_MUTE_TASKS_KEY)
            .apply()
    }
}
