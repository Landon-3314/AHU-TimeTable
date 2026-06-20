package com.gh.timetable

object AppUpdaterIntentPolicy {
    fun unknownSourcesPackageUri(packageName: String): String {
        return "package:$packageName"
    }

    fun fileProviderAuthority(packageName: String): String {
        return "$packageName.fileprovider"
    }
}
