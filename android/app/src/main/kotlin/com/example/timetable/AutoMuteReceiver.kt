package com.example.timetable

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AutoMuteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val mode = intent.getStringExtra("mode") ?: return
        AutoMuteScheduler.setMode(context, mode)
    }
}
