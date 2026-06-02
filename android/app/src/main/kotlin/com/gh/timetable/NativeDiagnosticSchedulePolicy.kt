package com.gh.timetable

data class DiagnosticScheduleResult(
    val success: Boolean,
    val reason: String? = null,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "success" to success,
            "reason" to reason,
        )
    }
}

object NativeDiagnosticSchedulePolicy {
    private const val SILENT_ALARM_SCHEDULE_FAILED = "silent_alarm_schedule_failed"
    private const val RESTORE_ALARM_SCHEDULE_FAILED = "restore_alarm_schedule_failed"

    fun result(
        silentScheduled: Boolean,
        restoreScheduled: Boolean,
    ): DiagnosticScheduleResult {
        if (!silentScheduled) {
            return DiagnosticScheduleResult(
                success = false,
                reason = SILENT_ALARM_SCHEDULE_FAILED,
            )
        }
        if (!restoreScheduled) {
            return DiagnosticScheduleResult(
                success = false,
                reason = RESTORE_ALARM_SCHEDULE_FAILED,
            )
        }
        return DiagnosticScheduleResult(success = true)
    }
}
