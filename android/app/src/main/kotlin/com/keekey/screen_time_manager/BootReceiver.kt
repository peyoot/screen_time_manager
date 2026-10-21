package com.screen_time_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机自启接收器（第 4 步）。
 *
 * 收到 BOOT_COMPLETED 后，若用户曾手动打开过应用（[PREF_USER_STARTED] 标记，
 * 由 MainActivity.onCreate 写入），则启动前台监控服务，恢复亮屏计时。
 *
 * 为什么标记写在 MainActivity 而不是 Application：开机广播本身就会拉起进程，
 * Application.onCreate 先于任何组件执行——若在那里写标记，任何一次开机都会
 * 无条件通过检查，"用户已启动过 App 并完成授权"的前提就失效了。
 *
 * 注意：本接收器以 android:exported="false" 声明；BOOT_COMPLETED 是受保护的
 * 系统广播，系统仍可送达非 exported 接收器。若个别 ROM 不触发，可改回
 * exported="true" 再验。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"

        private const val PREFS_NAME = "monitor_bootstrap"
        private const val PREF_USER_STARTED = "user_started"

        /** 部分厂商（HTC/联想等）的快速开机广播，语义等同 BOOT_COMPLETED。 */
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"

        /** 用户手动打开过应用时调用（MainActivity.onCreate）。 */
        fun markUserStarted(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(PREF_USER_STARTED, true).apply()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, ACTION_QUICKBOOT_POWERON -> Unit
            else -> return
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PREF_USER_STARTED, false)) {
            Log.d(TAG, "skip boot start: user never opened the app")
            return
        }
        Log.d(TAG, "boot completed: starting monitor service")
        ScreenMonitorService.start(context)
    }
}
