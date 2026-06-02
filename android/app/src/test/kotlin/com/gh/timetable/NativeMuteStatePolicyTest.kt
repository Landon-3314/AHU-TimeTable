package com.gh.timetable

import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeMuteStatePolicyTest {
    @Test
    fun `active app-owned restore survives schedule refresh`() {
        assertTrue(
            NativeMuteStatePolicy.shouldRetainRestore(
                mutedByApp = true,
                restoreAtMillis = 2_000L,
                now = 1_000L,
            ),
        )
    }

    @Test
    fun `expired restore is not retained`() {
        assertFalse(
            NativeMuteStatePolicy.shouldRetainRestore(
                mutedByApp = true,
                restoreAtMillis = 1_000L,
                now = 1_000L,
            ),
        )
    }

    @Test
    fun `restore without app ownership is not retained`() {
        assertFalse(
            NativeMuteStatePolicy.shouldRetainRestore(
                mutedByApp = false,
                restoreAtMillis = 2_000L,
                now = 1_000L,
            ),
        )
    }

    @Test
    fun `manual vibration is not overridden`() {
        assertFalse(
            NativeMuteStatePolicy.shouldRestoreOwnedMute(
                mutedByApp = true,
                currentRingerMode = AudioManager.RINGER_MODE_VIBRATE,
                appAppliedRingerMode = AudioManager.RINGER_MODE_SILENT,
            ),
        )
    }

    @Test
    fun `app-owned silent mode can be restored when forced`() {
        assertTrue(
            NativeMuteStatePolicy.shouldRestoreOwnedMute(
                mutedByApp = true,
                currentRingerMode = AudioManager.RINGER_MODE_SILENT,
                appAppliedRingerMode = AudioManager.RINGER_MODE_SILENT,
            ),
        )
    }

    @Test
    fun `refresh merges active app-owned restore work omitted by new plan`() {
        val retained =
            NativeMuteStatePolicy.retainedRestoreWork(
                storedItems =
                    listOf(
                        alarmItem(
                            index = 7,
                            silentAtMillis = 500L,
                            restoreAtMillis = 2_000L,
                            reminderAtMillis = 750L,
                        ),
                    ),
                mutedIndexes = setOf(7),
                now = 1_000L,
            )

        val merged =
            NativeMuteStatePolicy.mergeRetainedRestoreWork(
                futureItems = emptyList(),
                retainedItems = retained,
            )

        assertTrue(merged.size == 1)
        assertTrue(merged.single().index == 7)
        assertTrue(merged.single().silentAtMillis == null)
        assertTrue(merged.single().reminderAtMillis == null)
        assertTrue(merged.single().restoreAtMillis == 2_000L)
    }

    @Test
    fun `refresh keeps earlier active restore when new work reuses index`() {
        val retained =
            listOf(
                alarmItem(
                    index = 7,
                    silentAtMillis = null,
                    restoreAtMillis = 2_000L,
                    reminderAtMillis = null,
                    windowStartAtMillis = 500L,
                    windowEndAtMillis = 2_000L,
                ),
            )

        val merged =
            NativeMuteStatePolicy.mergeRetainedRestoreWork(
                futureItems =
                    listOf(
                        alarmItem(
                            index = 7,
                            silentAtMillis = 3_000L,
                            restoreAtMillis = 4_000L,
                            reminderAtMillis = null,
                            windowStartAtMillis = 3_000L,
                            windowEndAtMillis = 4_000L,
                        ),
                    ),
                retainedItems = retained,
            )

        assertEquals(1, merged.size)
        assertEquals(2_000L, merged.single().restoreAtMillis)
        assertEquals(500L, merged.single().windowStartAtMillis)
        assertEquals(2_000L, merged.single().windowEndAtMillis)
    }

    @Test
    fun `future mute falls back to manual reminder when exact alarm is missing`() {
        assertTrue(
            NativeMuteStatePolicy.shouldScheduleManualMuteFallback(
                silentAtMillis = 2_000L,
                now = 1_000L,
                canScheduleExact = false,
                canChangeRingerMode = true,
            ),
        )
        assertFalse(
            NativeMuteStatePolicy.shouldScheduleManualMuteFallback(
                silentAtMillis = 2_000L,
                now = 1_000L,
                canScheduleExact = true,
                canChangeRingerMode = true,
            ),
        )
        assertTrue(
            NativeMuteStatePolicy.shouldScheduleManualMuteFallback(
                silentAtMillis = 2_000L,
                now = 1_000L,
                canScheduleExact = true,
                canChangeRingerMode = false,
            ),
        )
        assertFalse(
            NativeMuteStatePolicy.shouldScheduleManualMuteFallback(
                silentAtMillis = 1_000L,
                now = 1_000L,
                canScheduleExact = false,
                canChangeRingerMode = true,
            ),
        )
    }

    private fun alarmItem(
        index: Int,
        silentAtMillis: Long?,
        restoreAtMillis: Long?,
        reminderAtMillis: Long?,
        windowStartAtMillis: Long? = null,
        windowEndAtMillis: Long? = null,
    ): NativeAlarmScheduler.AlarmItem {
        return NativeAlarmScheduler.AlarmItem(
            index = index,
            silentAtMillis = silentAtMillis,
            restoreAtMillis = restoreAtMillis,
            reminderAtMillis = reminderAtMillis,
            title = null,
            content = null,
            windowStartAtMillis = windowStartAtMillis,
            windowEndAtMillis = windowEndAtMillis,
        )
    }
}
