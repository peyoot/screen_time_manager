package com.screen_time_manager

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * 屏幕监控前台服务（第 2 步）。
 *
 * 职责：
 * 1. 以前台服务（Android 14+ 类型 specialUse）保活，进程保持高优先级；
 * 2. 在服务内**动态注册**亮灭屏接收器（SCREEN_ON / SCREEN_OFF /
 *    USER_PRESENT 不能通过 manifest 静态注册接收），事件经
 *    [ScreenEventBus] → EventChannel 推给 Dart 状态机；
 * 3. 展示一条低干扰常驻通知。
 *
 * Dart 侧的状态机运行在 [ScreenMonitorApp] 缓存的 FlutterEngine 中，
 * 不随 Activity 销毁而停止；本服务保证承载引擎的进程不被系统回收。
 */
class ScreenMonitorService : Service() {

    private var receiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                // 亮屏与解锁都视为"屏幕可交互"；重复事件在 Dart 状态机侧
                // 因状态相同会被直接忽略。
                Intent.ACTION_SCREEN_ON,
                Intent.ACTION_USER_PRESENT -> ScreenEventBus.emitScreenOn(true)
                Intent.ACTION_SCREEN_OFF -> ScreenEventBus.emitScreenOn(false)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startAsForeground()
        registerScreenReceiver()
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 被系统回收后尽量自动重建；重建后 Dart 侧 startMonitoring 幂等。
        return START_STICKY
    }

    override fun onBind(intent: Intent?): Nothing? = null

    override fun onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(screenReceiver)
            receiverRegistered = false
        }
        running = false
        super.onDestroy()
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        // 屏幕广播只接受运行时动态注册；API 33+ 必须显式声明导出标志，
        // 系统广播使用 NOT_EXPORTED 即可接收。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
        receiverRegistered = true

        // 注册后立即同步一次当前屏幕状态，避免漏推服务启动前的状态。
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        ScreenEventBus.emitScreenOn(powerManager.isInteractive)
    }

    private fun startAsForeground() {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen Time Monitor")
            .setContentText("Monitoring active")
            .setSmallIcon(R.drawable.ic_screen_monitor)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // Android 14+ 必须声明 specialUse 类型；低版本走双参重载。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Screen monitoring",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Persistent notification for screen-time monitoring"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "screen_monitor"
        private const val NOTIFICATION_ID = 1001

        /** 服务是否存活（供 isMonitoring 查询，进程内可见）。 */
        @Volatile
        var running: Boolean = false
            private set

        /** 启动前台服务（8.0+ 必须走 startForegroundService）。 */
        fun start(context: Context) {
            val intent = Intent(context, ScreenMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止监控服务。 */
        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenMonitorService::class.java))
        }
    }
}
