package com.gh.timetable

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val UPDATER_PREFS = "app_updater"
private const val LAST_DOWNLOADED_APK_PATH = "lastDownloadedApkPath"
private const val LAST_DOWNLOADED_APK_VERSION_CODE = "lastDownloadedApkVersionCode"
private const val PENDING_INSTALL_APK_PATH = "pendingInstallApkPath"

class AppUpdaterHandler(private val activity: FlutterActivity) {
    fun onResume() {
        cleanupInstalledDownloadedApk()
        retryPendingInstallAfterPermission()
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getVersionName" -> result.success(currentVersionName())
                "getVersionCode" -> result.success(currentVersionCode())
                "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "getDownloadDirectory" -> result.success(downloadDirectory().absolutePath)
                "installApk" -> installApk(
                    call.argument<String>("path"),
                    call.argument<Number>("versionCode")?.toLong(),
                    result,
                )
                "cleanupDownloadedApks" -> {
                    cleanupDownloadedApk()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            Log.w(
                "AppUpdater",
                "Updater method ${call.method} failed: ${error.message}",
                error,
            )
            when (call.method) {
                "getVersionName" -> result.success("")
                "getVersionCode" -> result.success(0)
                "getSupportedAbis" -> result.success(emptyList<String>())
                "getDownloadDirectory" -> result.success(null)
                "installApk" -> result.success(false)
                "cleanupDownloadedApks" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    private fun currentVersionCode(): Long {
        val packageInfo = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
    }

    private fun currentVersionName(): String {
        val packageInfo = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return packageInfo.versionName ?: ""
    }

    private fun downloadDirectory(): File {
        return File(requireExternalFilesDir(), "updates")
    }

    private fun requireExternalFilesDir(): File {
        return activity.getExternalFilesDir(null)
            ?: throw IllegalStateException("External files directory is unavailable")
    }

    private fun installApk(
        path: String?,
        targetVersionCode: Long?,
        result: MethodChannel.Result,
    ) {
        if (path.isNullOrBlank()) {
            result.success(false)
            return
        }
        val apkFile = File(path)
        if (!isAllowedDownloadedApk(apkFile) || !apkFile.exists()) {
            result.success(false)
            return
        }

        if (!canRequestApkInstalls()) {
            val settingsOpened = openUnknownAppSourcesSettings()
            if (settingsOpened) {
                rememberPendingInstall(apkFile, targetVersionCode)
            }
            result.success(if (settingsOpened) "permissionSettingsOpened" else "failed")
            return
        }

        return if (openApkInstaller(apkFile)) {
            rememberDownloadedApk(apkFile, targetVersionCode)
            result.success("installerOpened")
        } else {
            result.success("failed")
        }
    }

    private fun canRequestApkInstalls(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppSourcesSettings(): Boolean {
        val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse(
                AppUpdaterIntentPolicy.unknownSourcesPackageUri(activity.packageName),
            )
        }
        return try {
            activity.startActivity(settingsIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun openApkInstaller(apkFile: File): Boolean {
        return try {
            val uri = FileProvider.getUriForFile(
                activity,
                AppUpdaterIntentPolicy.fileProviderAuthority(activity.packageName),
                apkFile,
            )
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            activity.startActivity(installIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun rememberDownloadedApk(apkFile: File, targetVersionCode: Long?) {
        val editor = activity.getSharedPreferences(UPDATER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(LAST_DOWNLOADED_APK_PATH, apkFile.absolutePath)
        if (targetVersionCode != null && targetVersionCode > 0L) {
            editor.putLong(LAST_DOWNLOADED_APK_VERSION_CODE, targetVersionCode)
        } else {
            editor.remove(LAST_DOWNLOADED_APK_VERSION_CODE)
        }
        editor.apply()
    }

    private fun rememberPendingInstall(apkFile: File, targetVersionCode: Long?) {
        val editor = activity.getSharedPreferences(UPDATER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PENDING_INSTALL_APK_PATH, apkFile.absolutePath)
        if (targetVersionCode != null && targetVersionCode > 0L) {
            editor.putLong(LAST_DOWNLOADED_APK_VERSION_CODE, targetVersionCode)
        }
        editor.apply()
    }

    private fun retryPendingInstallAfterPermission() {
        if (!canRequestApkInstalls()) {
            return
        }
        val prefs = activity.getSharedPreferences(UPDATER_PREFS, Context.MODE_PRIVATE)
        val path = prefs.getString(PENDING_INSTALL_APK_PATH, null) ?: return
        val apkFile = File(path)
        if (!isAllowedDownloadedApk(apkFile) || !apkFile.exists()) {
            prefs.edit()
                .remove(PENDING_INSTALL_APK_PATH)
                .remove(LAST_DOWNLOADED_APK_VERSION_CODE)
                .apply()
            return
        }
        val installerOpened = openApkInstaller(apkFile)
        val editor = prefs.edit().remove(PENDING_INSTALL_APK_PATH)
        if (installerOpened) {
            editor.putString(LAST_DOWNLOADED_APK_PATH, apkFile.absolutePath)
        } else {
            editor.remove(LAST_DOWNLOADED_APK_VERSION_CODE)
        }
        editor.apply()
    }

    private fun cleanupInstalledDownloadedApk() {
        val prefs = activity.getSharedPreferences(UPDATER_PREFS, Context.MODE_PRIVATE)
        val targetVersionCode = prefs.getLong(LAST_DOWNLOADED_APK_VERSION_CODE, -1L)
        if (targetVersionCode <= 0L || currentVersionCode() < targetVersionCode) {
            return
        }
        cleanupDownloadedApk()
    }

    private fun cleanupDownloadedApk() {
        val prefs = activity.getSharedPreferences(UPDATER_PREFS, Context.MODE_PRIVATE)
        val path = prefs.getString(LAST_DOWNLOADED_APK_PATH, null)
        if (!path.isNullOrBlank()) {
            val apkFile = File(path)
            if (isAllowedDownloadedApk(apkFile) && apkFile.exists()) {
                apkFile.delete()
            }
        }
        prefs.edit()
            .remove(LAST_DOWNLOADED_APK_PATH)
            .remove(LAST_DOWNLOADED_APK_VERSION_CODE)
            .remove(PENDING_INSTALL_APK_PATH)
            .apply()
    }

    private fun isAllowedDownloadedApk(file: File): Boolean {
        val downloads = downloadDirectory().canonicalFile
        val candidate = file.canonicalFile
        val name = candidate.name
        return candidate.parentFile == downloads &&
            name.startsWith("timetable-") &&
            name.endsWith(".apk")
    }
}
