package com.gh.timetable

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeAlarmTimePolicyTest {
    @Test
    fun `timezone rebase preserves local date time fields`() {
        val source = calendar("Asia/Shanghai", 2026, Calendar.JUNE, 8, 9, 30, 15, 321)

        val rebased =
            NativeAlarmTimePolicy.rebaseTimestamp(
                timestamp = source.timeInMillis,
                sourceTimeZoneId = "Asia/Shanghai",
                targetTimeZoneId = "America/New_York",
            )

        assertLocalDateTime(
            timestamp = rebased!!,
            timeZoneId = "America/New_York",
            year = 2026,
            month = Calendar.JUNE,
            day = 8,
            hour = 9,
            minute = 30,
            second = 15,
            millisecond = 321,
        )
    }

    @Test
    fun `timezone rebase applies target daylight saving rules`() {
        val source = calendar("Asia/Shanghai", 2026, Calendar.JULY, 8, 9, 30)

        val rebased =
            NativeAlarmTimePolicy.rebaseTimestamp(
                timestamp = source.timeInMillis,
                sourceTimeZoneId = "Asia/Shanghai",
                targetTimeZoneId = "America/New_York",
            )

        val target = calendar("America/New_York", 2026, Calendar.JULY, 8, 9, 30)
        assertEquals(target.timeInMillis, rebased)
    }

    @Test
    fun `missing source timezone keeps timestamp unchanged`() {
        assertEquals(
            123_456L,
            NativeAlarmTimePolicy.rebaseTimestamp(
                timestamp = 123_456L,
                sourceTimeZoneId = null,
                targetTimeZoneId = "America/New_York",
            ),
        )
    }

    @Test
    fun `alarm item rebase updates every timestamp field`() {
        val item =
            alarmItem(
                silentAtMillis = 1L,
                restoreAtMillis = 2L,
                reminderAtMillis = 3L,
                windowStartAtMillis = 4L,
                windowEndAtMillis = 5L,
            )

        val rebased =
            NativeAlarmTimePolicy.rebaseAlarmItems(
                items = listOf(item),
                sourceTimeZoneId = "UTC",
                targetTimeZoneId = "Asia/Shanghai",
            ).single()

        assertEquals(-28_799_999L, rebased.silentAtMillis)
        assertEquals(-28_799_998L, rebased.restoreAtMillis)
        assertEquals(-28_799_997L, rebased.reminderAtMillis)
        assertEquals(-28_799_996L, rebased.windowStartAtMillis)
        assertEquals(-28_799_995L, rebased.windowEndAtMillis)
    }

    @Test
    fun `today course rebase updates start and end`() {
        val item =
            NativeStateStore.TodayCourseItem(
                courseName = "Math",
                location = "Room 101",
                startAtMillis = 1L,
                endAtMillis = 2L,
            )

        val rebased =
            NativeAlarmTimePolicy.rebaseTodayCourseItems(
                items = listOf(item),
                sourceTimeZoneId = "UTC",
                targetTimeZoneId = "Asia/Shanghai",
            ).single()

        assertEquals(-28_799_999L, rebased.startAtMillis)
        assertEquals(-28_799_998L, rebased.endAtMillis)
    }

    @Test
    fun `reschedule plan reconciles rebased expired items before dropping them`() {
        val plan =
            NativeAlarmTimePolicy.prepareReschedule(
                alarmItems =
                    listOf(
                        alarmItem(
                            silentAtMillis = null,
                            restoreAtMillis = 1L,
                            reminderAtMillis = null,
                            windowStartAtMillis = null,
                            windowEndAtMillis = 1L,
                        ),
                    ),
                todayCourseItems = emptyList(),
                sourceTimeZoneId = "UTC",
                targetTimeZoneId = "Asia/Shanghai",
                now = 0L,
            )

        assertEquals(1, plan.reconciliationItems.size)
        assertTrue(plan.futureItems.isEmpty())
    }

    @Test
    fun `reschedule plan keeps status window with future end`() {
        val plan =
            NativeAlarmTimePolicy.prepareReschedule(
                alarmItems =
                    listOf(
                        alarmItem(
                            silentAtMillis = null,
                            restoreAtMillis = null,
                            reminderAtMillis = null,
                            windowStartAtMillis = 1L,
                            windowEndAtMillis = 100L,
                        ),
                    ),
                todayCourseItems = emptyList(),
                sourceTimeZoneId = null,
                targetTimeZoneId = "UTC",
                now = 50L,
            )

        assertEquals(1, plan.futureItems.size)
    }

    @Test
    fun `reschedule receiver accepts clock change broadcasts`() {
        assertTrue(BootRescheduleReceiver.isAllowedAction("android.intent.action.TIMEZONE_CHANGED"))
        assertTrue(BootRescheduleReceiver.isAllowedAction("android.intent.action.TIME_SET"))
        assertTrue(BootRescheduleReceiver.isAllowedAction("android.intent.action.DATE_CHANGED"))
    }

    private fun alarmItem(
        silentAtMillis: Long?,
        restoreAtMillis: Long?,
        reminderAtMillis: Long?,
        windowStartAtMillis: Long?,
        windowEndAtMillis: Long?,
    ): NativeAlarmScheduler.AlarmItem {
        return NativeAlarmScheduler.AlarmItem(
            index = 1,
            silentAtMillis = silentAtMillis,
            restoreAtMillis = restoreAtMillis,
            reminderAtMillis = reminderAtMillis,
            title = null,
            content = null,
            windowStartAtMillis = windowStartAtMillis,
            windowEndAtMillis = windowEndAtMillis,
        )
    }

    private fun calendar(
        timeZoneId: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0,
        millisecond: Int = 0,
    ): Calendar {
        return Calendar.getInstance(TimeZone.getTimeZone(timeZoneId)).apply {
            clear()
            set(year, month, day, hour, minute, second)
            set(Calendar.MILLISECOND, millisecond)
        }
    }

    private fun assertLocalDateTime(
        timestamp: Long,
        timeZoneId: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        millisecond: Int,
    ) {
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(timeZoneId)).apply {
            timeInMillis = timestamp
        }
        assertEquals(year, calendar.get(Calendar.YEAR))
        assertEquals(month, calendar.get(Calendar.MONTH))
        assertEquals(day, calendar.get(Calendar.DAY_OF_MONTH))
        assertEquals(hour, calendar.get(Calendar.HOUR_OF_DAY))
        assertEquals(minute, calendar.get(Calendar.MINUTE))
        assertEquals(second, calendar.get(Calendar.SECOND))
        assertEquals(millisecond, calendar.get(Calendar.MILLISECOND))
    }
}
