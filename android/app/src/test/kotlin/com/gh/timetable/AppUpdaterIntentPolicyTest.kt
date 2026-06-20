package com.gh.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AppUpdaterIntentPolicyTest {
    @Test
    fun `unknown app sources URI uses the real package name`() {
        val uri = AppUpdaterIntentPolicy.unknownSourcesPackageUri("com.gh.timetable")

        assertEquals("package:com.gh.timetable", uri.toString())
        assertFalse(uri.toString().contains("FlutterActivity"))
        assertFalse(uri.toString().contains("packageName"))
    }

    @Test
    fun `file provider authority uses application id`() {
        val authority = AppUpdaterIntentPolicy.fileProviderAuthority("com.gh.timetable")

        assertEquals("com.gh.timetable.fileprovider", authority)
        assertFalse(authority.contains("FlutterActivity"))
        assertFalse(authority.contains("packageName"))
    }
}
