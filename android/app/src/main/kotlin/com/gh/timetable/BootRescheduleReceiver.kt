package com.gh.timetable

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val action = intent.action.orEmpty()
        if (action !in ALLOWED_ACTIONS) {
            Log.w(TAG, "Ignoring unexpected reschedule action=$action")
            return
        }

        Log.d(TAG, "Reschedule requested by action=$action")
        runCatching {
            NativeAlarmScheduler.rescheduleStored(context)
            TimetableForegroundService.requestRefresh(context)
        }.onFailure { error ->
            Log.e(TAG, "Failed to reschedule native mute alarms", error)
        }
    }

    companion object {
        private const val TAG = "BootRescheduleReceiver"
        private val ALLOWED_ACTIONS = setOf(
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
        )
    }
}
