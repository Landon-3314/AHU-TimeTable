package com.example.timetable

import android.Manifest
import android.app.AlarmManager
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
import android.view.ScrollCaptureCallback
import android.view.ScrollCaptureSession
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import java.util.function.Consumer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private const val REQUEST_POST_NOTIFICATIONS = 5021
private const val NATIVE_ALARM_CHANNEL = "com.timetable/native_alarm"
private const val SCROLL_CAPTURE_CHANNEL = "app.scroll_capture"
private const val TAG = "MainActivity"

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scrollCaptureChannel: MethodChannel? = null
    private var didInstallScrollCaptureCallback = false

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        scrollCaptureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCROLL_CAPTURE_CHANNEL,
        )

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
                    NativeAlarmScheduler.scheduleOneMinuteMuteTest(this)
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

    override fun onResume() {
        super.onResume()
        installScrollCaptureCallbackIfNeeded()
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

    private fun installScrollCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || didInstallScrollCaptureCallback) {
            return
        }

        val flutterView = findFlutterView(window.decorView) ?: return
        flutterView.scrollCaptureHint = View.SCROLL_CAPTURE_HINT_INCLUDE
        flutterView.setScrollCaptureCallback(FlutterScrollCaptureCallback(flutterView))
        didInstallScrollCaptureCallback = true
    }

    private fun invokeFlutterMethod(
        method: String,
        arguments: Any? = null,
        onSuccess: (Any?) -> Unit,
        onFailure: () -> Unit,
    ) {
        val channel = scrollCaptureChannel
        if (channel == null) {
            onFailure()
            return
        }

        mainHandler.post {
            channel.invokeMethod(
                method,
                arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        onSuccess(result)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.w(TAG, "Flutter method $method failed: $errorCode $errorMessage")
                        onFailure()
                    }

                    override fun notImplemented() {
                        Log.w(TAG, "Flutter method $method not implemented")
                        onFailure()
                    }
                },
            )
        }
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) {
            return view
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                val child = view.getChildAt(index)
                val match = findFlutterView(child)
                if (match != null) {
                    return match
                }
            }
        }
        return null
    }

    private fun findTextureView(view: View): TextureView? {
        if (view is TextureView) {
            return view
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                val child = view.getChildAt(index)
                val match = findTextureView(child)
                if (match != null) {
                    return match
                }
            }
        }
        return null
    }

    private fun parseScrollableTarget(raw: Any?): ScrollableTarget? {
        val map = raw as? Map<*, *> ?: return null
        val id = map["id"] as? String ?: return null
        val left = (map["left"] as? Number)?.toFloat() ?: return null
        val top = (map["top"] as? Number)?.toFloat() ?: return null
        val width = (map["width"] as? Number)?.toFloat() ?: return null
        val height = (map["height"] as? Number)?.toFloat() ?: return null
        val pixels = (map["pixels"] as? Number)?.toFloat() ?: return null
        val maxScrollExtent = (map["maxScrollExtent"] as? Number)?.toFloat() ?: return null
        val viewportDimension = (map["viewportDimension"] as? Number)?.toFloat() ?: return null
        if (width <= 0f || height <= 0f || viewportDimension <= 0f) {
            return null
        }
        return ScrollableTarget(
            id = id,
            bounds = Rect(
                left.roundToInt(),
                top.roundToInt(),
                (left + width).roundToInt(),
                (top + height).roundToInt(),
            ),
            pixels = pixels,
            maxScrollExtent = maxScrollExtent,
            viewportDimension = viewportDimension,
        )
    }

    private fun chooseBestScrollable(raw: Any?, flutterView: FlutterView): ScrollableTarget? {
        val items = raw as? List<*> ?: return null
        var bestTarget: ScrollableTarget? = null
        var bestArea = 0
        val viewportBounds = Rect(0, 0, flutterView.width, flutterView.height)

        for (item in items) {
            val candidate = parseScrollableTarget(item) ?: continue
            if (candidate.maxScrollExtent <= 1f) {
                continue
            }

            val visibleBounds = Rect(candidate.bounds)
            if (!visibleBounds.intersect(viewportBounds)) {
                continue
            }

            val visibleHeight = min(
                visibleBounds.height().toFloat(),
                candidate.viewportDimension,
            ).roundToInt()
            if (visibleHeight <= 0) {
                continue
            }

            val adjusted = candidate.copy(
                bounds = Rect(
                    visibleBounds.left,
                    visibleBounds.top,
                    visibleBounds.right,
                    visibleBounds.top + visibleHeight,
                ),
            )
            val area = adjusted.bounds.width() * adjusted.bounds.height()
            if (area > bestArea) {
                bestArea = area
                bestTarget = adjusted
            }
        }

        return bestTarget
    }

    private fun parseScrollResult(raw: Any?): ScrollMetricsSnapshot? {
        val map = raw as? Map<*, *> ?: return null
        val ok = map["ok"] as? Boolean ?: false
        if (!ok) {
            return null
        }
        val pixels = (map["pixels"] as? Number)?.toFloat() ?: return null
        val maxScrollExtent = (map["maxScrollExtent"] as? Number)?.toFloat() ?: return null
        val viewportDimension = (map["viewportDimension"] as? Number)?.toFloat() ?: return null
        return ScrollMetricsSnapshot(
            pixels = pixels,
            maxScrollExtent = maxScrollExtent,
            viewportDimension = viewportDimension,
        )
    }

    private data class ScrollableTarget(
        val id: String,
        val bounds: Rect,
        val pixels: Float,
        val maxScrollExtent: Float,
        val viewportDimension: Float,
    )

    private data class ScrollMetricsSnapshot(
        val pixels: Float,
        val maxScrollExtent: Float,
        val viewportDimension: Float,
    )

    private data class ActiveCaptureState(
        val id: String,
        val bounds: Rect,
        val startPixels: Float,
        var maxScrollExtent: Float,
        var viewportDimension: Float,
    )

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private inner class FlutterScrollCaptureCallback(
        private val flutterView: FlutterView,
        ) : ScrollCaptureCallback {
        private var activeCaptureState: ActiveCaptureState? = null

        override fun onScrollCaptureSearch(
            cancellationSignal: CancellationSignal,
            onReady: Consumer<Rect>,
        ) {
            invokeFlutterMethod(
                method = "describeScrollables",
                onSuccess = { raw ->
                    if (cancellationSignal.isCanceled) {
                        onReady.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    val target = chooseBestScrollable(raw, flutterView)
                    activeCaptureState =
                        target?.let {
                            ActiveCaptureState(
                                id = it.id,
                                bounds = Rect(it.bounds),
                                startPixels = it.pixels,
                                maxScrollExtent = it.maxScrollExtent,
                                viewportDimension = it.viewportDimension,
                            )
                        }
                    onReady.accept(target?.bounds ?: Rect())
                },
                onFailure = {
                    activeCaptureState = null
                    onReady.accept(Rect())
                },
            )
        }

        override fun onScrollCaptureStart(
            session: ScrollCaptureSession,
            cancellationSignal: CancellationSignal,
            onReady: Runnable,
        ) {
            val state = activeCaptureState
            if (state == null || cancellationSignal.isCanceled) {
                onReady.run()
                return
            }

            invokeFlutterMethod(
                method = "prepareCapture",
                arguments = mapOf("id" to state.id),
                onSuccess = {
                    onReady.run()
                },
                onFailure = {
                    onReady.run()
                },
            )
        }

        override fun onScrollCaptureImageRequest(
            session: ScrollCaptureSession,
            cancellationSignal: CancellationSignal,
            captureArea: Rect,
            onComplete: Consumer<Rect>,
        ) {
            val state = activeCaptureState
            if (state == null || captureArea.isEmpty || cancellationSignal.isCanceled) {
                onComplete.accept(Rect())
                return
            }

            val targetPixels =
                (state.startPixels + captureArea.top).coerceIn(0f, state.maxScrollExtent)
            invokeFlutterMethod(
                method = "scrollTo",
                arguments = mapOf("id" to state.id, "offset" to targetPixels),
                onSuccess = { raw ->
                    if (cancellationSignal.isCanceled) {
                        onComplete.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    val scrollMetrics = parseScrollResult(raw)
                    if (scrollMetrics == null) {
                        onComplete.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    state.maxScrollExtent = scrollMetrics.maxScrollExtent
                    state.viewportDimension = scrollMetrics.viewportDimension
                    val captured = captureBitmapIntoSession(
                        session = session,
                        captureArea = captureArea,
                        state = state,
                        currentPixels = scrollMetrics.pixels,
                    )
                    onComplete.accept(captured ?: Rect())
                },
                onFailure = {
                    onComplete.accept(Rect())
                },
            )
        }

        override fun onScrollCaptureEnd(onReady: Runnable) {
            val state = activeCaptureState
            activeCaptureState = null
            if (state == null) {
                onReady.run()
                return
            }

            invokeFlutterMethod(
                method = "restoreCapture",
                arguments = mapOf("id" to state.id),
                onSuccess = {
                    onReady.run()
                },
                onFailure = {
                    onReady.run()
                },
            )
        }

        private fun captureBitmapIntoSession(
            session: ScrollCaptureSession,
            captureArea: Rect,
            state: ActiveCaptureState,
            currentPixels: Float,
        ): Rect? {
            val textureView = findTextureView(flutterView) ?: return null
            val bitmap = textureView.bitmap ?: return null

            return try {
                val scrollDelta = currentPixels - state.startPixels
                val visibleLocalTop = max(0f, captureArea.top - scrollDelta)
                val visibleLocalBottom = min(
                    state.bounds.height().toFloat(),
                    captureArea.bottom - scrollDelta,
                )
                if (visibleLocalBottom <= visibleLocalTop) {
                    return null
                }

                val availableTop = (visibleLocalTop + scrollDelta).roundToInt()
                val availableBottom = (visibleLocalBottom + scrollDelta).roundToInt()
                val availableRect = Rect(
                    captureArea.left,
                    availableTop,
                    captureArea.right,
                    availableBottom,
                )

                val sourceRect = Rect(
                    state.bounds.left + captureArea.left,
                    state.bounds.top + visibleLocalTop.roundToInt(),
                    state.bounds.left + captureArea.right,
                    state.bounds.top + visibleLocalBottom.roundToInt(),
                )
                sourceRect.intersect(0, 0, bitmap.width, bitmap.height)
                if (sourceRect.isEmpty) {
                    return null
                }

                val canvas = session.surface.lockCanvas(availableRect)
                try {
                    canvas.drawBitmap(bitmap, sourceRect, RectF(availableRect), null)
                } finally {
                    session.surface.unlockCanvasAndPost(canvas)
                }
                availableRect
            } catch (error: Throwable) {
                Log.w(TAG, "Scroll capture frame failed", error)
                null
            } finally {
                bitmap.recycle()
            }
        }
    }
}
