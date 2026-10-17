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
 * 闹钟触发拉起新进程时，Application.onCreate（ScreenMonitorApp）先于
 * 本接收器执行并重建缓存 FlutterEngine；onReceive 只做一件事——调
 * [ScreenMonitorService.start]，不触碰任何尚未初始化的组件，保证
 * 进程刚启动时不会崩溃。
 *
 * 幂等：onTaskRemoved 同时调度了精确（~1s）与非精确（~5s）两个闹钟，
 * 两者可能先后触发；服务已在运行时直接跳过第二次重启。
 *
 * Android 12+ 在非精确闹钟触发等场景下可能拒绝后台启动前台服务，
 * 捕获后静默放弃——此时仍有 START_STICKY 与开机自启两条恢复路径。
 */
class ServiceRestartReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        // 双闹钟去重：服务已存活（进程未被杀或另一个闹钟已拉起）则不再重启。
        if (ScreenMonitorService.running) {
            Log.d(TAG, "monitor service already running, skip duplicate restart")
            return
        }
        Log.d(TAG, "restart alarm fired, restarting monitor service")
        runCatching { ScreenMonitorService.start(context) }
            .onFailure { Log.w(TAG, "foreground service restart rejected: $it") }
    }

    companion object {
        private const val TAG = "ServiceRestartReceiver"
    }
}
