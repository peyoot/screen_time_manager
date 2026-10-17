package com.screen_time_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 划掉应用后的自动重启接收器。
 *
 * 必须在 manifest 中静态注册：进程被杀后动态注册的接收器不复存在，
 * 只有静态注册才能由系统在闹钟触发时拉起新进程投递。
 * 收到 [ScreenMonitorService] 的重启闹钟后以前台服务方式恢复监控。
 *
 * Android 12+ 在无精确闹钟豁免时可能拒绝后台启动前台服务，
 * 捕获后静默放弃——此时仍有 START_STICKY 与开机自启两条恢复路径。
 */
class ServiceRestartReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "restart alarm fired, restarting monitor service")
        runCatching { ScreenMonitorService.start(context) }
            .onFailure { Log.w(TAG, "foreground service restart rejected: $it") }
    }

    companion object {
        private const val TAG = "ServiceRestartReceiver"
    }
}
