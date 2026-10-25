package com.keekey.screen_time_manager

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device Admin 接收器：仅申请 `force-lock`（允许调用 lockNow() 熄屏）。
 *
 * 用户需在系统设置里授权一次（DevicePolicyManager.createAddAdminActiveIntent 弹窗），
 * 之后本应用即可静默熄屏。其他策略（wipe-data、reset-password 等）均未声明。
 */
class ScreenMonitorDeviceAdmin : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }
}
