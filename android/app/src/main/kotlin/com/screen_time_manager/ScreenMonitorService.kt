package com.screen_time_manager

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * 屏幕监控前台服务（第 2 步）+ 音量变化 ContentObserver（第 3 步）。
 *
 * 职责：
 * 1. 前台保活 + 亮灭屏广播监听；
 * 2. **音量键紧急退出的兜底通路**：OEM ROM 常对 Activity.dispatchKeyEvent
 *    和无障碍服务提前拦截音量键，但系统 Settings.System.CONTENT_URI
 *    的音量值变化回调不受影响——无论什么通路（硬件键、系统图标、AIDL）
 *    改音量都会触发 onChange。我们在此 diff 前后值判定方向，喂给
 *    [EmergencyKeyController]。
 *
 * 关键细节：音量在 0 或 max 档按同方向不会产生变化事件（保持不变），
 * 所以在密码录入窗口 arm 时预调到中间档，保证每次按键都有变化信号。
 * ContentObserver 不主动吞事件，靠控制器内的 debounce（60ms 内同方向）
 * 去重 Activity 主通路和本通路同时上报的情况。
 */
class ScreenMonitorService : Service() {

    companion object {
        private const val TAG = "ScreenMonitorService"

        private const val CHANNEL_ID = "screen_monitor"
        private const val NOTIFICATION_ID = 1001

        /** 划掉应用后的重启闹钟 request code（与通知/其他 PendingIntent 隔离）。 */
        private const val RESTART_REQUEST_CODE = 2001

        /** 划掉应用后延迟多久尝试重启前台服务。 */
        private const val RESTART_DELAY_MS = 1000L

        @Volatile
        var running: Boolean = false
            private set

        /**
         * 紧急退出路径置 true：抑制 [onTaskRemoved] 的自动重启闹钟，
         * 避免"彻底退出应用"后 1 秒又被闹钟拉起复活。
         * 服务每次 onCreate 时复位为 false。
         */
        @Volatile
        var suppressAutoRestart: Boolean = false

        /** 兜底音量通路是否启用（服务启动即注册，进程存活期间一直监听）。 */
        @Volatile
        var volumeObserverEnabled: Boolean = true

        fun start(context: Context) {
            val intent = Intent(context, ScreenMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenMonitorService::class.java))
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var receiverRegistered = false
    private var volumeObserverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON,
                Intent.ACTION_USER_PRESENT -> ScreenEventBus.emitScreenOn(true)
                Intent.ACTION_SCREEN_OFF -> ScreenEventBus.emitScreenOn(false)
            }
        }
    }

    /** 兜底：观察音量值变化 → diff 判定方向 → 喂控制器。 */
    private val volumeObserver = object : ContentObserver(mainHandler) {
        private var lastVolume = -1
        private var lastMaxVolume = -1
        private var lastStream = 0

        fun initCurrentVolume() {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            lastVolume = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            lastMaxVolume = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        }

        override fun onChange(selfChange: Boolean, uri: Uri?) {
            if (!volumeObserverEnabled) return
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            Log.d(TAG, "volume observe cur=$cur max=$max last=$lastVolume")
            if (lastVolume >= 0 && lastVolume != cur) {
                val isUp = cur > lastVolume
                EmergencyKeyController.onVolumeChanged(isUp)
            }
            lastVolume = cur
            lastMaxVolume = max
            // 边界档：若当前已达 0 或 max 且仍处于密码窗口，主动拉回中间档
            // 保证后续按键产生变化信号。非密码窗口不干预用户正常调音量。
            if (EmergencyKeyController.capturingVolumeKeys && (cur == 0 || cur == max)) {
                val mid = max / 2
                if (mid != cur) {
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, mid, 0)
                    // onChange 会被 setStreamVolume 再次触发，下一次 diff 自然生效。
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        suppressAutoRestart = false
        createNotificationChannel()
        startAsForeground()
        registerScreenReceiver()
        registerVolumeObserver()
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onBind(intent: Intent?): Nothing? = null

    override fun onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(screenReceiver)
            receiverRegistered = false
        }
        unregisterVolumeObserver()
        running = false
        super.onDestroy()
    }

    /**
     * 用户从最近任务划掉应用：多数国产 ROM（ZUXOS/MIUI/EMUI 等）会直接杀掉
     * 整个进程。此处通过精确闹钟安排约 1 秒后重启前台服务——进程已死时由
     * 系统拉起新进程投递给 manifest 静态注册的 [ServiceRestartReceiver]，
     * 再以前台服务方式恢复监控（Application 会重建缓存 FlutterEngine，
     * Dart 侧从 day_snapshot 恢复当日进度，数据延续）。
     *
     * 边界说明：
     * - 若 ROM 的划卡等价于"强制停止"，系统会取消已注册的闹钟且
     *   START_STICKY 不再生效，应用层无法自愈——只能依赖权限引导页的
     *   "自启动 + 电池不优化"白名单降低被杀概率；
     * - 紧急退出会先置 [suppressAutoRestart]，避免退出后被闹钟重新拉起。
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (suppressAutoRestart || !running) return
        scheduleRestart()
    }

    /** 用精确闹钟安排一次 [ServiceRestartReceiver] 重启（详见 [onTaskRemoved]）。 */
    private fun scheduleRestart() {
        val alarmManager = getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            RESTART_REQUEST_CODE,
            Intent(this, ServiceRestartReceiver::class.java),
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )
        val triggerAt = SystemClock.elapsedRealtime() + RESTART_DELAY_MS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            // 无精确闹钟权限（Android 14+ 默认不授予）：退化为非精确闹钟尽力重启。
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent,
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent,
            )
        }
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
        receiverRegistered = true

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        ScreenEventBus.emitScreenOn(powerManager.isInteractive)
    }

    private fun registerVolumeObserver() {
        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            volumeObserver,
        )
        volumeObserverRegistered = true
        volumeObserver.initCurrentVolume()
    }

    private fun unregisterVolumeObserver() {
        if (volumeObserverRegistered) {
            contentResolver.unregisterContentObserver(volumeObserver)
            volumeObserverRegistered = false
        }
    }

    private fun startAsForeground() {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen Time Monitor")
            .setContentText("Monitoring active")
            .setSmallIcon(R.drawable.ic_screen_monitor)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

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
}

