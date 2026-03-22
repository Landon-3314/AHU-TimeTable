package com.example.timetable

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
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
            "app.auto_mute",
        ).setMethodCallHandler { call, result ->
            handleAutoMuteCall(call, result)
        }
    }

    private fun handleAutoMuteCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "hasPermission" -> result.success(
                AutoMuteScheduler.isNotificationPolicyGranted(this),
            )

            "openPermissionSettings" -> {
                AutoMuteScheduler.openNotificationPolicySettings(this)
                result.success(null)
            }

            "setSilentNow" -> {
                AutoMuteScheduler.setMode(this, "vibrate")
                result.success(null)
            }

            "replaceTasks" -> {
                val rawTasks = call.argument<List<Map<String, Any?>>>("tasks").orEmpty()
                val tasks = rawTasks.mapNotNull { map ->
                    val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
                    val timestamp =
                        (map["timestamp"] as? Number)?.toLong() ?: return@mapNotNull null
                    val mode = map["mode"] as? String ?: return@mapNotNull null
                    AutoMuteTask(
                        id = id,
                        timestamp = timestamp,
                        mode = mode,
                    )
                }

                AutoMuteScheduler.replaceTasks(this, tasks)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
