package com.gh.timetable

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

object RomPermissionHelper {
    private val romComponents =
        listOf(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            ),
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            ),
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            ),
            ComponentName(
                "com.samsung.android.sm_cn",
                "com.samsung.android.sm_cn.ui.ram.RamActivity",
            ),
            ComponentName(
                "com.meizu.safe",
                "com.meizu.safe.security.SecurityMainActivity",
            ),
        )

    fun openBackgroundPermissionSettings(context: Context): Boolean {
        romComponents.forEach { component ->
            val intent =
                Intent().apply {
                    this.component = component
                    putExtra("package_name", context.packageName)
                    putExtra("packageName", context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            try {
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the next ROM target before falling back.
            }
        }

        val fallbackIntent =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        context.startActivity(fallbackIntent)
        return false
    }
}

