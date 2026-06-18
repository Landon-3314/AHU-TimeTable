package com.gh.timetable

import java.util.Calendar
import java.util.TimeZone

data class NativeAlarmReschedulePlan(
    val reconciliationItems: List<NativeAlarmScheduler.AlarmItem>,
    val futureItems: List<NativeAlarmScheduler.AlarmItem>,
    val todayCourseItems: List<NativeStateStore.TodayCourseItem>,
)

object NativeAlarmTimePolicy {
    fun rebaseTimestamp(
        timestamp: Long?,
        sourceTimeZoneId: String?,
        targetTimeZoneId: String,
    ): Long? {
        if (timestamp == null ||
            sourceTimeZoneId == null ||
            sourceTimeZoneId == targetTimeZoneId
        ) {
            return timestamp
        }

        val source = Calendar.getInstance(TimeZone.getTimeZone(sourceTimeZoneId)).apply {
            timeInMillis = timestamp
        }
        return Calendar.getInstance(TimeZone.getTimeZone(targetTimeZoneId)).apply {
            clear()
            set(
                source.get(Calendar.YEAR),
                source.get(Calendar.MONTH),
                source.get(Calendar.DAY_OF_MONTH),
                source.get(Calendar.HOUR_OF_DAY),
                source.get(Calendar.MINUTE),
                source.get(Calendar.SECOND),
            )
            set(Calendar.MILLISECOND, source.get(Calendar.MILLISECOND))
        }.timeInMillis
    }

    fun rebaseAlarmItems(
        items: List<NativeAlarmScheduler.AlarmItem>,
        sourceTimeZoneId: String?,
        targetTimeZoneId: String,
    ): List<NativeAlarmScheduler.AlarmItem> {
        return items.map { item ->
            item.copy(
                silentAtMillis =
                    rebaseTimestamp(item.silentAtMillis, sourceTimeZoneId, targetTimeZoneId),
                restoreAtMillis =
                    rebaseTimestamp(item.restoreAtMillis, sourceTimeZoneId, targetTimeZoneId),
                reminderAtMillis =
                    rebaseTimestamp(item.reminderAtMillis, sourceTimeZoneId, targetTimeZoneId),
                windowStartAtMillis =
                    rebaseTimestamp(item.windowStartAtMillis, sourceTimeZoneId, targetTimeZoneId),
                windowEndAtMillis =
                    rebaseTimestamp(item.windowEndAtMillis, sourceTimeZoneId, targetTimeZoneId),
            )
        }
    }

    fun rebaseTodayCourseItems(
        items: List<NativeStateStore.TodayCourseItem>,
        sourceTimeZoneId: String?,
        targetTimeZoneId: String,
    ): List<NativeStateStore.TodayCourseItem> {
        return items.map { item ->
            item.copy(
                startAtMillis =
                    rebaseTimestamp(item.startAtMillis, sourceTimeZoneId, targetTimeZoneId)
                        ?: item.startAtMillis,
                endAtMillis =
                    rebaseTimestamp(item.endAtMillis, sourceTimeZoneId, targetTimeZoneId)
                        ?: item.endAtMillis,
            )
        }
    }

    fun prepareReschedule(
        alarmItems: List<NativeAlarmScheduler.AlarmItem>,
        todayCourseItems: List<NativeStateStore.TodayCourseItem>,
        sourceTimeZoneId: String?,
        targetTimeZoneId: String,
        now: Long,
    ): NativeAlarmReschedulePlan {
        val rebasedAlarmItems =
            rebaseAlarmItems(
                items = alarmItems,
                sourceTimeZoneId = sourceTimeZoneId,
                targetTimeZoneId = targetTimeZoneId,
            )
        return NativeAlarmReschedulePlan(
            reconciliationItems = rebasedAlarmItems,
            futureItems = rebasedAlarmItems.filter { item -> item.hasFutureWork(now) },
            todayCourseItems =
                rebaseTodayCourseItems(
                    items = todayCourseItems,
                    sourceTimeZoneId = sourceTimeZoneId,
                    targetTimeZoneId = targetTimeZoneId,
                ),
        )
    }

    private fun NativeAlarmScheduler.AlarmItem.hasFutureWork(now: Long): Boolean {
        return (silentAtMillis ?: Long.MIN_VALUE) > now ||
            (restoreAtMillis ?: Long.MIN_VALUE) > now ||
            (reminderAtMillis ?: Long.MIN_VALUE) > now ||
            (windowEndAtMillis ?: Long.MIN_VALUE) > now
    }
}
