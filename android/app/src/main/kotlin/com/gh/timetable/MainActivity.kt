package com.gh.timetable

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.MotionEvent
import android.view.ScrollCaptureCallback
import android.view.ScrollCaptureSession
import android.view.TextureView
import android.view.View
import android.view.View.AccessibilityDelegate
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.TimeZone
import java.util.function.Consumer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private const val REQUEST_POST_NOTIFICATIONS = 5021
private const val NATIVE_ALARM_CHANNEL = "com.timetable/native_alarm"
private const val SCROLL_CAPTURE_CHANNEL = "app.scroll_capture"
private const val SCROLL_CAPTURE_DIAG_TAG = "ScrollCaptureDiag"
private const val APP_UPDATER_CHANNEL = "app.updater"
private const val APP_STORAGE_CHANNEL = "app.storage"
private const val NOTIFICATION_DIAG_TAG = "NotificationDiag"
private const val REMINDER_CHANNEL_ID = "timetable_reminders"
private const val UPDATER_PREFS = "app_updater"
private const val LAST_DOWNLOADED_APK_PATH = "lastDownloadedApkPath"
private const val LAST_DOWNLOADED_APK_VERSION_CODE = "lastDownloadedApkVersionCode"
private const val PENDING_INSTALL_APK_PATH = "pendingInstallApkPath"
private const val ENABLE_SCROLL_CAPTURE_OVERLAY_DIAGNOSTICS = false

class MainActivity : FlutterActivity() {
    companion object {
        private var notificationPermissionResult: MethodChannel.Result? = null
    }
    private var scrollCaptureChannel: MethodChannel? = null
    private lateinit var scrollCaptureCoordinator: ScrollCaptureCoordinator
    private lateinit var appUpdaterHandler: AppUpdaterHandler

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Resolve stale permission result from a previous Activity instance
        // that was destroyed while the permission dialog was still showing.
        notificationPermissionResult?.let { stale ->
            notificationLog("configureFlutterEngine resolving stale permission result")
            stale.error(
                "PERMISSION_REQUEST_CANCELLED",
                "Activity was recreated during permission request",
                null,
            )
            notificationPermissionResult = null
        }

        scrollCaptureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCROLL_CAPTURE_CHANNEL,
        )
        scrollCaptureCoordinator = ScrollCaptureCoordinator(this) { scrollCaptureChannel }
        appUpdaterHandler = AppUpdaterHandler(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.timezone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> {
                    val timezone = TimeZone.getDefault().id
                    notificationLog("timezone getLocalTimezone result=$timezone")
                    result.success(timezone)
                }
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
                "notificationDiagnostics" -> result.success(notificationDiagnostics())
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
                        parseAlarmItem(entry)
                    }
                    val rawTodayCourses = call.argument<List<Any?>>("todayCourses") ?: emptyList()
                    val todayCourses = rawTodayCourses.mapNotNull { row ->
                        val entry = row as? Map<*, *> ?: return@mapNotNull null
                        parseTodayCourse(entry)
                    }
                    NativeAlarmScheduler.scheduleAll(this, items)
                    NativeStateStore.saveTodayCourses(this, todayCourses)
                    TimetableForegroundService.requestRefresh(this)
                    result.success(true)
                }

                "reconcileMuteState" -> {
                    val restoreActiveAppMute =
                        call.argument<Boolean>("restoreActiveAppMute") ?: false
                    NativeAlarmScheduler.reconcileMuteState(
                        context = this,
                        restoreActiveAppMute = restoreActiveAppMute,
                    )
                    result.success(true)
                }

                "cancelAllClasses" -> {
                    NativeAlarmScheduler.cancelAll(this)
                    TimetableForegroundService.requestRefresh(this)
                    result.success(true)
                }

                "setForegroundServiceEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    TimetableForegroundService.setEnabled(this, enabled)
                    result.success(true)
                }

                "refreshForegroundService" -> {
                    TimetableForegroundService.requestRefresh(this)
                    result.success(true)
                }

                "openRomPermissionSettings" -> {
                    result.success(RomPermissionHelper.openBackgroundPermissionSettings(this))
                }

                "runOneMinuteMuteTest" -> {
                    result.success(
                        NativeAlarmScheduler.scheduleOneMinuteMuteTest(this).toMap(),
                    )
                }

                "runTimedMuteTest" -> {
                    val muteAfterSeconds = (call.argument<Number>("muteAfterSeconds") ?: 30).toLong()
                    val restoreAfterSeconds =
                        (call.argument<Number>("restoreAfterSeconds") ?: 60).toLong()
                    result.success(
                        NativeAlarmScheduler.scheduleDiagnosticMuteWindow(
                            context = this,
                            silentDelayMillis = muteAfterSeconds.coerceAtLeast(1L) * 1000L,
                            restoreDelayMillis =
                                restoreAfterSeconds.coerceAtLeast(muteAfterSeconds + 1L) * 1000L,
                        ).toMap(),
                    )
                }

                "cancelTimedMuteTest" -> {
                    NativeAlarmScheduler.cancelDiagnosticMuteWindow(this)
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATER_CHANNEL,
        ).setMethodCallHandler(appUpdaterHandler::handle)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_STORAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getExternalFilesDir" -> result.success(getExternalFilesDir(null)?.absolutePath)
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        scrollCaptureCoordinator.onResume()
        appUpdaterHandler.onResume()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        scrollCaptureCoordinator.onWindowFocusChanged(hasFocus)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        scrollCaptureCoordinator.handleTouchEvent(event)
        return super.dispatchTouchEvent(event)
    }

    override fun onPause() {
        scrollCaptureCoordinator.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        scrollCaptureCoordinator.onDestroy()
        scrollCaptureChannel = null
        super.onDestroy()
    }

    private fun parseAlarmItem(entry: Map<*, *>): NativeAlarmScheduler.AlarmItem? {
        val index = (entry["courseIndex"] as? Number)?.toInt() ?: return null
        return NativeAlarmScheduler.AlarmItem(
            index = index,
            silentAtMillis = (entry["silentAtMillis"] as? Number)?.toLong(),
            restoreAtMillis = (entry["restoreAtMillis"] as? Number)?.toLong(),
            reminderAtMillis = (entry["reminderAtMillis"] as? Number)?.toLong(),
            title = entry["title"] as? String,
            content = entry["content"] as? String,
            notificationId = (entry["notificationId"] as? Number)?.toInt(),
            reminderAction =
                (entry["reminderAction"] as? String)
                    ?: NativeAlarmScheduler.ACTION_REMIND_CLASS,
            scheduleType =
                (entry["scheduleType"] as? String)
                    ?: NativeAlarmScheduler.SCHEDULE_TYPE_COURSE,
            courseName = entry["courseName"] as? String,
            location = entry["location"] as? String,
            windowStartAtMillis = (entry["windowStartAtMillis"] as? Number)?.toLong(),
            windowEndAtMillis = (entry["windowEndAtMillis"] as? Number)?.toLong(),
        )
    }

    private fun parseTodayCourse(entry: Map<*, *>): NativeStateStore.TodayCourseItem? {
        val courseName = entry["courseName"] as? String ?: return null
        val startAtMillis = (entry["startAtMillis"] as? Number)?.toLong() ?: return null
        val endAtMillis = (entry["endAtMillis"] as? Number)?.toLong() ?: return null
        return NativeStateStore.TodayCourseItem(
            courseName = courseName,
            location = entry["location"] as? String,
            startAtMillis = startAtMillis,
            endAtMillis = endAtMillis,
        )
    }

    private fun hasPostNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            notificationLog(
                "hasPostNotificationPermission sdk=${Build.VERSION.SDK_INT} result=true pre-33",
            )
            return true
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        notificationLog(
            "hasPostNotificationPermission sdk=${Build.VERSION.SDK_INT} result=$granted",
        )
        return granted
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            notificationLog("requestNotificationPermission skipped pre-33 result=true")
            result.success(true)
            return
        }

        if (hasPostNotificationPermission()) {
            notificationLog("requestNotificationPermission already granted")
            result.success(true)
            return
        }

        if (notificationPermissionResult != null) {
            notificationLog("requestNotificationPermission rejected: request already in progress")
            result.error("REQUEST_IN_PROGRESS", "Permission request already in progress", null)
            return
        }

        notificationLog("requestNotificationPermission launching runtime dialog")
        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun notificationDiagnostics(): Map<String, Any?> {
        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val notificationsEnabled =
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.getNotificationChannel(REMINDER_CHANNEL_ID)
        } else {
            null
        }
        val diagnostics = mutableMapOf<String, Any?>(
            "packageName" to packageName,
            "sdkInt" to Build.VERSION.SDK_INT,
            "postNotificationsPermissionGranted" to hasPostNotificationPermission(),
            "areNotificationsEnabled" to notificationsEnabled,
            "exactAlarmPermissionGranted" to hasExactAlarmPermission(),
            "notificationPolicyAccessGranted" to notificationManager.isNotificationPolicyAccessGranted,
            "reminderChannelId" to REMINDER_CHANNEL_ID,
            "reminderChannelExists" to (channel != null),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channel != null) {
            diagnostics["reminderChannelImportance"] = channel.importance
            diagnostics["reminderChannelCanBypassDnd"] = channel.canBypassDnd()
            diagnostics["reminderChannelSound"] = channel.sound?.toString()
            diagnostics["reminderChannelVibration"] = channel.shouldVibrate()
        }
        notificationLog("notificationDiagnostics result=$diagnostics")
        return diagnostics
    }

    private fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasUseExactAlarmPermission =
                checkSelfPermission(Manifest.permission.USE_EXACT_ALARM) ==
                    PackageManager.PERMISSION_GRANTED
            if (hasUseExactAlarmPermission) {
                notificationLog("hasExactAlarmPermission true via USE_EXACT_ALARM")
                return true
            }
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

        val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(settingsIntent)
        } catch (_: Exception) {}
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            notificationLog(
                "onRequestPermissionsResult POST_NOTIFICATIONS granted=$granted " +
                    "grantResults=${grantResults.joinToString()}",
            )
            notificationPermissionResult?.success(granted)
            notificationPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun notificationLog(message: String) {
        Log.d(NOTIFICATION_DIAG_TAG, "${System.currentTimeMillis()} $message")
    }
}
