package com.gh.timetable

import android.content.Context
import android.os.Build
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

object NativeStateStore {
    private const val KEY_ALARM_ITEMS = "alarm_items_json"
    private const val KEY_ALARM_ITEMS_TIME_ZONE_ID = "alarm_items_time_zone_id"
    private const val KEY_TODAY_COURSES = "today_courses_json"
    private const val KEY_LAST_SCHEDULED_COUNT = "last_scheduled_count"
    private const val KEY_FOREGROUND_SERVICE_ENABLED = "foreground_service_enabled"
    private const val KEY_LAST_RINGER_MODE = "last_ringer_mode"
    private const val KEY_LAST_RINGER_MODE_AT = "last_ringer_mode_at"
    private const val KEY_LAST_ALARM_ACTION = "last_alarm_action"
    private const val KEY_LAST_ALARM_INDEX = "last_alarm_index"

    data class TodayCourseItem(
        val courseName: String,
        val location: String?,
        val startAtMillis: Long,
        val endAtMillis: Long,
    )

    fun saveAlarmItems(
        context: Context,
        items: List<NativeAlarmScheduler.AlarmItem>,
    ) {
        val jsonArray = JSONArray()
        items.forEach { item ->
            jsonArray.put(
                JSONObject().apply {
                    put("index", item.index)
                    putOpt("silentAtMillis", item.silentAtMillis)
                    putOpt("restoreAtMillis", item.restoreAtMillis)
                    putOpt("reminderAtMillis", item.reminderAtMillis)
                    putOpt("title", item.title)
                    putOpt("content", item.content)
                    putOpt("notificationId", item.notificationId)
                    put("reminderAction", item.reminderAction)
                    put("scheduleType", item.scheduleType)
                    putOpt("courseName", item.courseName)
                    putOpt("location", item.location)
                    putOpt("windowStartAtMillis", item.windowStartAtMillis)
                    putOpt("windowEndAtMillis", item.windowEndAtMillis)
                },
            )
        }

        prefs(context).edit()
            .putString(KEY_ALARM_ITEMS, jsonArray.toString())
            .putString(KEY_ALARM_ITEMS_TIME_ZONE_ID, TimeZone.getDefault().id)
            .putInt(KEY_LAST_SCHEDULED_COUNT, items.size)
            .apply()
    }

    fun loadAlarmItems(context: Context): List<NativeAlarmScheduler.AlarmItem> {
        val raw = prefs(context).getString(KEY_ALARM_ITEMS, null) ?: return emptyList()
        return runCatching {
            val jsonArray = JSONArray(raw)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    add(
                        NativeAlarmScheduler.AlarmItem(
                            index = item.optInt("index"),
                            silentAtMillis = item.optNullableLong("silentAtMillis"),
                            restoreAtMillis = item.optNullableLong("restoreAtMillis"),
                            reminderAtMillis = item.optNullableLong("reminderAtMillis"),
                            title = item.optNullableString("title"),
                            content = item.optNullableString("content"),
                            notificationId = item.optNullableInt("notificationId"),
                            reminderAction =
                                item.optNullableString("reminderAction")
                                    ?: NativeAlarmScheduler.ACTION_REMIND_CLASS,
                            scheduleType =
                                item.optNullableString("scheduleType")
                                    ?: NativeAlarmScheduler.SCHEDULE_TYPE_COURSE,
                            courseName = item.optNullableString("courseName"),
                            location = item.optNullableString("location"),
                            windowStartAtMillis = item.optNullableLong("windowStartAtMillis"),
                            windowEndAtMillis = item.optNullableLong("windowEndAtMillis"),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun saveTodayCourses(
        context: Context,
        items: List<TodayCourseItem>,
    ) {
        val jsonArray = JSONArray()
        items.forEach { item ->
            jsonArray.put(
                JSONObject().apply {
                    put("courseName", item.courseName)
                    putOpt("location", item.location)
                    put("startAtMillis", item.startAtMillis)
                    put("endAtMillis", item.endAtMillis)
                },
            )
        }

        prefs(context).edit()
            .putString(KEY_TODAY_COURSES, jsonArray.toString())
            .apply()
    }

    fun loadTodayCourses(context: Context): List<TodayCourseItem> {
        val raw = prefs(context).getString(KEY_TODAY_COURSES, null) ?: return emptyList()
        return runCatching {
            val jsonArray = JSONArray(raw)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    val courseName = item.optNullableString("courseName") ?: continue
                    val startAtMillis = item.optNullableLong("startAtMillis") ?: continue
                    val endAtMillis = item.optNullableLong("endAtMillis") ?: continue
                    add(
                        TodayCourseItem(
                            courseName = courseName,
                            location = item.optNullableString("location"),
                            startAtMillis = startAtMillis,
                            endAtMillis = endAtMillis,
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun getLastScheduledCount(context: Context): Int {
        return prefs(context).getInt(KEY_LAST_SCHEDULED_COUNT, 0)
    }

    fun getAlarmItemsTimeZoneId(context: Context): String? {
        return prefs(context).getString(KEY_ALARM_ITEMS_TIME_ZONE_ID, null)
    }

    fun clearAlarmItems(context: Context) {
        prefs(context).edit()
            .remove(KEY_ALARM_ITEMS)
            .remove(KEY_ALARM_ITEMS_TIME_ZONE_ID)
            .remove(KEY_TODAY_COURSES)
            .putInt(KEY_LAST_SCHEDULED_COUNT, 0)
            .apply()
    }

    fun setForegroundServiceEnabled(
        context: Context,
        enabled: Boolean,
    ) {
        prefs(context).edit().putBoolean(KEY_FOREGROUND_SERVICE_ENABLED, enabled).apply()
    }

    fun isForegroundServiceEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_FOREGROUND_SERVICE_ENABLED, false)
    }

    fun setMutedByApp(
        context: Context,
        index: Int,
        mutedByApp: Boolean,
    ) {
        prefs(context).edit().putBoolean(mutedKey(index), mutedByApp).apply()
    }

    fun wasMutedByApp(
        context: Context,
        index: Int,
    ): Boolean {
        return prefs(context).getBoolean(mutedKey(index), false)
    }

    fun clearMutedByApp(
        context: Context,
        index: Int,
    ) {
        prefs(context).edit()
            .remove(mutedKey(index))
            .remove(originalRingerModeKey(index))
            .remove(appliedRingerModeKey(index))
            .apply()
    }

    fun recordOriginalRingerMode(
        context: Context,
        index: Int,
        ringerMode: Int,
    ) {
        prefs(context).edit().putInt(originalRingerModeKey(index), ringerMode).apply()
    }

    fun originalRingerMode(
        context: Context,
        index: Int,
    ): Int? {
        val key = originalRingerModeKey(index)
        val values = prefs(context)
        return if (values.contains(key)) values.getInt(key, -1) else null
    }

    fun recordAppliedRingerMode(
        context: Context,
        index: Int,
        ringerMode: Int,
    ) {
        prefs(context).edit().putInt(appliedRingerModeKey(index), ringerMode).apply()
    }

    fun appliedRingerMode(
        context: Context,
        index: Int,
    ): Int? {
        val key = appliedRingerModeKey(index)
        val values = prefs(context)
        return if (values.contains(key)) values.getInt(key, -1) else null
    }

    fun recordAlarmAction(
        context: Context,
        action: String,
        index: Int,
    ) {
        prefs(context).edit()
            .putString(KEY_LAST_ALARM_ACTION, action)
            .putInt(KEY_LAST_ALARM_INDEX, index)
            .apply()
    }

    fun recordRingerMode(
        context: Context,
        ringerMode: Int,
    ) {
        prefs(context).edit()
            .putInt(KEY_LAST_RINGER_MODE, ringerMode)
            .putLong(KEY_LAST_RINGER_MODE_AT, System.currentTimeMillis())
            .apply()
    }

    private fun prefs(context: Context) =
        storageContext(context).getSharedPreferences(
            NativeAlarmScheduler.PREFS,
            Context.MODE_PRIVATE,
        )

    private fun storageContext(context: Context): Context {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val deviceContext = context.createDeviceProtectedStorageContext()
            runCatching {
                deviceContext.moveSharedPreferencesFrom(context, NativeAlarmScheduler.PREFS)
            }
            return deviceContext
        }
        return context
    }

    private fun mutedKey(index: Int) = "app_did_mute_$index"

    private fun originalRingerModeKey(index: Int) = "original_ringer_mode_$index"

    private fun appliedRingerModeKey(index: Int) = "app_applied_ringer_mode_$index"

    private fun JSONObject.optNullableLong(key: String): Long? {
        return if (has(key) && !isNull(key)) optLong(key) else null
    }

    private fun JSONObject.optNullableInt(key: String): Int? {
        return if (has(key) && !isNull(key)) optInt(key) else null
    }

    private fun JSONObject.optNullableString(key: String): String? {
        return if (has(key) && !isNull(key)) optString(key) else null
    }
}
