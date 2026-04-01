package com.example.timetable

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

private const val REQUEST_POST_NOTIFICATIONS = 5021
private const val NATIVE_ALARM_CHANNEL = "com.timetable/native_alarm"

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.timezone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationPermission" -> result.success(
                    hasPostNotificationPermission(),
                )
                "requestNotificationPermission" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAllClasses" -> {
                    val raw = call.argument<List<Any?>>("classes") ?: emptyList()
                    val items = raw.mapNotNull { row ->
                        val entry = row as? Map<*, *> ?: return@mapNotNull null
                        val silent = (entry["silentAtMillis"] as? Number)?.toLong()
                        val restore = (entry["restoreAtMillis"] as? Number)?.toLong()
                        val index = (entry["courseIndex"] as? Number)?.toInt()
                        if (silent == null || restore == null || index == null) {
                            null
                        } else {
                            NativeAlarmScheduler.AlarmItem(
                                index = index,
                                silentAtMillis = silent,
                                restoreAtMillis = restore,
                                reminderAtMillis = (entry["reminderAtMillis"] as? Number)?.toLong(),
                                title = entry["title"] as? String,
                                content = entry["content"] as? String,
                                reminderAction =
                                    (entry["reminderAction"] as? String)
                                        ?: NativeAlarmScheduler.ACTION_REMIND_CLASS,
                            )
                        }
                    }
                    NativeAlarmScheduler.scheduleAll(this, items)
                    result.success(true)
                }

                "cancelAllClasses" -> {
                    NativeAlarmScheduler.cancelAll(this)
                    result.success(true)
                }

                "hasExactAlarmPermission" -> {
                    result.success(hasExactAlarmPermission())
                }

                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(true)
                }

                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }

                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasPostNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (hasPostNotificationPermission()) {
            result.success(true)
            return
        }

        if (notificationPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "Permission request already in progress", null)
            return
        }

        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(directIntent)
        } catch (_: Exception) {
            startActivity(fallbackIntent)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            notificationPermissionResult?.success(granted)
            notificationPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
