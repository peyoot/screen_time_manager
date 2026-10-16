package com.screen_time_manager

import android.Manifest
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * 应用唯一 Activity。
 *
 * 通过 [getCachedEngineId] 复用 [ScreenMonitorApp] 预创建并缓存的
 * FlutterEngine：通道只在引擎创建时注册一次，Activity 重建/销毁
 * （旋转、退后台被回收）都不影响引擎内的 Dart 状态机。
 *
 * [ActivityTracker] 静态持有当前 Activity 的弱引用，供 intervention 通道
 * 的 lockScreen（DevicePolicyManager 需要 Activity）和 startLockTask/
 * stopLockTask（必须在 Activity 实例上调用）使用。
 */
class MainActivity : FlutterActivity() {

    /**
     * 休息期间轮询屏幕固定状态：公开 SDK 没有 LockTask 退出回调
     * （onLockTaskModeExiting 是 @hide），用 [getLockTaskModeState] 轮询。
     * 一旦发现用户退出固定（仍停留在本页的情况），立即重新固定。
     */
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lockTaskChecker = object : Runnable {
        override fun run() {
            if (RestGuard.armed) {
                val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                // 已处于固定模式时不再重复调用 startLockTask，避免系统反复弹
                // "应用已固定"toast。
                if (!am.isInLockTaskMode) {
                    runCatching { startLockTask() }
                }
            }
            mainHandler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun getCachedEngineId(): String = ScreenMonitorApp.ENGINE_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ActivityTracker.onActivityResumed(this)
        ensureNotificationPermission()
    }

    override fun onResume() {
        super.onResume()
        ActivityTracker.onActivityResumed(this)
        mainHandler.post(lockTaskChecker)
    }

    override fun onPause() {
        mainHandler.removeCallbacks(lockTaskChecker)
        super.onPause()
        ActivityTracker.onActivityPaused(this)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(lockTaskChecker)
        ActivityTracker.onActivityDestroyed(this)
        super.onDestroy()
    }

    /** Android 13+ 首次启动时申请通知权限，保证前台服务常驻通知可见。 */
    private companion object {
        const val CHECK_INTERVAL_MS = 5000L
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }
}
