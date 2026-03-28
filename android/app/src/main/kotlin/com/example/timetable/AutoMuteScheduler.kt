package com.example.timetable

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log

private const val AUTO_MUTE_PREFS = "auto_mute_prefs"
private const val SAVED_MUSIC_VOLUME_KEY = "saved_music_volume"
private const val HAS_SAVED_VOLUME_KEY = "has_saved_volume"

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
        Log.d("DND_DEBUG_NATIVE", "setMode invoked, mode=$mode")
        if (!isNotificationPolicyGranted(context)) {
            Log.e("DND_DEBUG_NATIVE", "setMode aborted: DND permission missing")
            return
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (mode) {
            "silent" -> enableClassMute(context, audioManager)
            else -> disableClassMute(context, audioManager)
        }
    }

    private fun enableClassMute(
        context: Context,
        audioManager: AudioManager,
    ) {
        Log.d("DND_DEBUG_NATIVE", "Step A: preparing to set ringerMode=SILENT")
        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        Log.d("DND_DEBUG_NATIVE", "Step A done: ringerMode=SILENT")

        val prefs = context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
        val currentMusic = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (currentMusic > 0) {
            prefs.edit()
                .putInt(SAVED_MUSIC_VOLUME_KEY, currentMusic)
                .putBoolean(HAS_SAVED_VOLUME_KEY, true)
                .apply()
            Log.d("DND_DEBUG_NATIVE", "Step B: saved current STREAM_MUSIC volume=$currentMusic")
        } else {
            Log.d(
                "DND_DEBUG_NATIVE",
                "Step B: current STREAM_MUSIC already 0, skip overwrite saved volume",
            )
        }

        Log.d("DND_DEBUG_NATIVE", "Step B: preparing to set STREAM_MUSIC volume=0")
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
        Log.d("DND_DEBUG_NATIVE", "Step B done: STREAM_MUSIC muted to 0")
    }

    private fun disableClassMute(
        context: Context,
        audioManager: AudioManager,
    ) {
        Log.d("DND_DEBUG_NATIVE", "Restore A: preparing to set ringerMode=NORMAL")
        audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
        Log.d("DND_DEBUG_NATIVE", "Restore A done: ringerMode=NORMAL")

        val prefs = context.getSharedPreferences(AUTO_MUTE_PREFS, Context.MODE_PRIVATE)
        val hasSavedVolume = prefs.getBoolean(HAS_SAVED_VOLUME_KEY, false)
        val fallbackMusic =
            (audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC) * 0.4f).toInt()
                .coerceAtLeast(1)
        val restoreMusic = if (hasSavedVolume) {
            prefs.getInt(SAVED_MUSIC_VOLUME_KEY, fallbackMusic)
        } else {
            fallbackMusic
        }

        Log.d(
            "DND_DEBUG_NATIVE",
            "Restore B: preparing to restore STREAM_MUSIC volume=$restoreMusic",
        )
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, restoreMusic, 0)
        Log.d("DND_DEBUG_NATIVE", "Restore B done: STREAM_MUSIC volume restored")

        prefs.edit()
            .remove(SAVED_MUSIC_VOLUME_KEY)
            .putBoolean(HAS_SAVED_VOLUME_KEY, false)
            .apply()
        Log.d("DND_DEBUG_NATIVE", "Restore cleanup done")
    }
}
