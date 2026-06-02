package com.gh.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeDiagnosticSchedulePolicyTest {
    @Test
    fun `diagnostic succeeds only when mute and restore alarms are scheduled`() {
        val result =
            NativeDiagnosticSchedulePolicy.result(
                silentScheduled = true,
                restoreScheduled = true,
            )

        assertTrue(result.success)
        assertNull(result.reason)
    }

    @Test
    fun `diagnostic reports mute alarm failure first`() {
        val result =
            NativeDiagnosticSchedulePolicy.result(
                silentScheduled = false,
                restoreScheduled = true,
            )

        assertFalse(result.success)
        assertEquals("silent_alarm_schedule_failed", result.reason)
    }

    @Test
    fun `diagnostic reports restore alarm failure`() {
        val result =
            NativeDiagnosticSchedulePolicy.result(
                silentScheduled = true,
                restoreScheduled = false,
            )

        assertFalse(result.success)
        assertEquals("restore_alarm_schedule_failed", result.reason)
    }
}
