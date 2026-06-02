package com.gh.timetable

object NativeMuteStatePolicy {
    fun shouldScheduleManualMuteFallback(
        silentAtMillis: Long?,
        now: Long,
        canScheduleExact: Boolean,
        canChangeRingerMode: Boolean,
    ): Boolean {
        return silentAtMillis != null &&
            silentAtMillis > now &&
            (!canScheduleExact || !canChangeRingerMode)
    }

    fun shouldRetainRestore(
        mutedByApp: Boolean,
        restoreAtMillis: Long?,
        now: Long,
    ): Boolean {
        return mutedByApp && restoreAtMillis != null && restoreAtMillis > now
    }

    fun shouldRestoreOwnedMute(
        mutedByApp: Boolean,
        currentRingerMode: Int,
        appAppliedRingerMode: Int?,
    ): Boolean {
        return mutedByApp &&
            appAppliedRingerMode != null &&
            currentRingerMode == appAppliedRingerMode
    }

    fun retainedRestoreWork(
        storedItems: List<NativeAlarmScheduler.AlarmItem>,
        mutedIndexes: Set<Int>,
        now: Long,
    ): List<NativeAlarmScheduler.AlarmItem> {
        return storedItems
            .filter { item ->
                shouldRetainRestore(
                    mutedByApp = item.index in mutedIndexes,
                    restoreAtMillis = item.restoreAtMillis,
                    now = now,
                )
            }
            .map { item ->
                item.copy(
                    silentAtMillis = null,
                    reminderAtMillis = null,
                )
            }
    }

    fun mergeRetainedRestoreWork(
        futureItems: List<NativeAlarmScheduler.AlarmItem>,
        retainedItems: List<NativeAlarmScheduler.AlarmItem>,
    ): List<NativeAlarmScheduler.AlarmItem> {
        val retainedByIndex = retainedItems.associateBy { item -> item.index }
        val mergedItems =
            futureItems.map { item ->
                val retainedItem = retainedByIndex[item.index] ?: return@map item
                mergeRetainedRestore(item, retainedItem)
            }
        val futureIndexes = futureItems.mapTo(mutableSetOf()) { item -> item.index }
        return mergedItems + retainedItems.filter { item -> item.index !in futureIndexes }
    }

    private fun mergeRetainedRestore(
        futureItem: NativeAlarmScheduler.AlarmItem,
        retainedItem: NativeAlarmScheduler.AlarmItem,
    ): NativeAlarmScheduler.AlarmItem {
        val retainedRestoreAt = retainedItem.restoreAtMillis ?: return futureItem
        val futureRestoreAt = futureItem.restoreAtMillis
        if (futureRestoreAt != null && futureRestoreAt <= retainedRestoreAt) {
            return futureItem
        }

        return futureItem.copy(
            silentAtMillis =
                futureItem.silentAtMillis?.takeIf { silentAtMillis ->
                    silentAtMillis < retainedRestoreAt
                },
            restoreAtMillis = retainedRestoreAt,
            windowStartAtMillis =
                retainedItem.windowStartAtMillis ?: futureItem.windowStartAtMillis,
            windowEndAtMillis = retainedItem.windowEndAtMillis ?: retainedRestoreAt,
        )
    }
}
