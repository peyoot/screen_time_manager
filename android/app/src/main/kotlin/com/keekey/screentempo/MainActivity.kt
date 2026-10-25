package com.keekey.screentempo

import android.Manifest
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

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
 *
 * 音量键紧急退出通路：[dispatchKeyEvent] 作为主路径——应用前台 / 屏幕固定
 * 期间，系统会把音量键先分发给当前窗口，再做调音量；在此处喂给
 * [EmergencyKeyController]，密码窗口内返回 true 即可抑制系统处理（音量不变、
 * HUD 不弹）。OEM ROM 若在 PhoneWindowManager 层提前拦截，则由
 * [ScreenMonitorService] 里的 ContentObserver 兜底。
 */
class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val lockTaskChecker = object : Runnable {
        override fun run() {
            if (RestGuard.armed) {
                val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                if (!am.isInLockTaskMode) runCatching { startLockTask() }
            }
            mainHandler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun getCachedEngineId(): String = ScreenMonitorApp.ENGINE_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 缓存引擎由 Application 预创建但**未执行 Dart**（后台拉起进程时不跑
        // Dart，避免无视图可附着导致引擎进入不可渲染状态）。此处窗口已就绪，
        // 在此触发 Dart 入口，保证 runApp() 时一定有 FlutterView 可附着。
        // 若 FlutterActivity 已自动执行（isExecutingDart 为 true）则跳过，
        // 不会重复启动 isolate。
        ensureDartEntrypoint()
        // 标记"用户手动打开过应用"：BootReceiver 依此决定开机后是否自启监控。
        BootReceiver.markUserStarted(this)
        ActivityTracker.onActivityResumed(this)
        ensureNotificationPermission()
    }

    /**
     * 确保缓存引擎执行了 Dart 入口。
     *
     * 引擎在 [ScreenMonitorApp] 中只创建空壳，Dart 入口推迟到本 Activity 窗口
     * 就绪后执行——这样无论是首次启动还是从后台（开机自启 / 划卡闹钟拉起）
     * 复用缓存引擎，runApp() 都发生在有 FlutterView 的上下文里，界面必出。
     * 已执行则直接返回，避免重复启动 Dart isolate。
     */
    private fun ensureDartEntrypoint() {
        val engine = FlutterEngineCache.getInstance()
            .get(ScreenMonitorApp.ENGINE_ID) ?: return
        if (!engine.dartExecutor.isExecutingDart) {
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
        }
    }

    override fun onResume() {
        super.onResume()
        // 悬浮层兜底遮罩必须让位：它悬浮在应用窗口之上，
        // 不移除会一直盖住刚拉回前台的休息页。
        InterventionOverlay.hide()
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

    /**
     * 音量键紧急退出主通路：系统先分发给当前窗口，再调音量。
     * 返回 true 表示吞掉，系统就不会调音量、也不会弹 HUD。
     * 长按重复事件（ACTION_DOWN + repeatCount > 0）不重复计数。
     */
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (event != null &&
            event.action == KeyEvent.ACTION_DOWN &&
            event.repeatCount == 0 &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            Log.d("MainActivity", "dispatchKeyEvent volume=${event.keyCode}")
            if (EmergencyKeyController.onKeyDown(event.keyCode)) return true
        }
        return super.dispatchKeyEvent(event)
    }

    private companion object {
        const val CHECK_INTERVAL_MS = 5000L
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
    }
}
