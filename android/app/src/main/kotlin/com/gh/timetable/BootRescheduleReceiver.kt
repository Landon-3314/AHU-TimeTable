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
    }
}
