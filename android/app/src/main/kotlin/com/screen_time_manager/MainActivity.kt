package com.screen_time_manager

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * 应用唯一 Activity。
 *
 * 通过 [getCachedEngineId] 复用 [ScreenMonitorApp] 预创建并缓存的
 * FlutterEngine：通道只在引擎创建时注册一次，Activity 重建/销毁
 * （旋转、退后台被回收）都不影响引擎内的 Dart 状态机。
 */
class MainActivity : FlutterActivity() {

    override fun getCachedEngineId(): String = ScreenMonitorApp.ENGINE_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationPermission()
    }

    /** Android 13+ 首次启动时申请通知权限，保证前台服务常驻通知可见。 */
    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            // 无论用户授予与否都不阻塞主流程：未授权时前台服务照常运行，
            // 仅常驻通知不展示（第 4 步会在设置页提供重新引导入口）。
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }
}
