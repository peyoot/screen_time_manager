package com.screen_time_manager

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 亮灭屏事件总线。
 *
 * Flutter 侧订阅 `screen_events` 时挂载 [EventChannel.EventSink]；
 * 第 2 步前台服务中动态注册的 SCREEN_ON / SCREEN_OFF 接收器将通过本总线推送事件。
 * 事件必须在主线程回调 sink（接收器默认注册在主线程 Looper 上）。
 */
object ScreenEventBus {
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    /** Flutter 订阅建立，绑定 sink。 */
    fun attach(sink: EventChannel.EventSink) {
        eventSink = sink
    }

    /** Flutter 取消订阅，解绑 sink。 */
    fun detach() {
        eventSink = null
    }

    /** 推送亮屏（true）/灭屏（false）事件；无订阅者时静默丢弃。 */
    fun emitScreenOn(isScreenOn: Boolean) {
        eventSink?.success(isScreenOn)
    }
}

/**
 * 平台通道注册器。
 *
 * - `screen_events`：订阅时先回推当前屏幕交互状态；亮灭屏广播由
 *   [ScreenMonitorService] 动态注册后经 [ScreenEventBus] 推送。
 * - `monitor`：启停 [ScreenMonitorService]（前台服务 + 屏幕广播）；
 *   另提供权限状态查询与系统设置页跳转。
 * - `intervention`：请求 / 撤销到点干预（拉 Activity 到前台 + 高优全屏通知 +
 *   悬浮层兜底）；休息期自动熄屏（DevicePolicyManager.lockNow）
 *   与屏幕固定（startLockTask / stopLockTask）。
 */
object ScreenMonitorChannels {
    private const val NAMESPACE = "com.screen_time_manager/platform"

    /** 到点干预通知渠道（高优先级 + 全屏 intent）。 */
    private const val ALERT_CHANNEL_ID = "screen_monitor_alert"
    private const val ALERT_NOTIFICATION_ID = 1002

    /** 启动 MainActivity 时透传当前阶段，供冷启动路由使用。 */
    private const val EXTRA_INTERVENTION_PHASE = "intervention_phase"
    private const val INTERVENTION_PHASE_RESTING = "resting"

    /** 监控是否运行（以前台服务存活为准）。 */
    val monitoring: Boolean
        get() = ScreenMonitorService.running

    /** 在给定引擎上注册全部平台通道。 */
    fun register(engine: FlutterEngine, context: Context) {
        registerScreenEvents(engine, context)
        registerMonitor(engine, context)
        registerIntervention(engine)
        registerCore(engine, context)
    }

    /**
     * `core` 通道：原生权威计时核心（[ScreenTimeCore]）的读写口。
     *
     * - `snapshot`：Dart 每秒读取权威状态镜像显示；
     * - `configure`：Dart 推送配置（阈值/休息时长/每日豁免上限），原生持久化；
     * - `manualRest` / `consumeExemption`：Dart 转发用户主动操作；
     * - `seedFromSnapshot`：升级迁移，原生无当日数据时用旧快照初始化。
     */
    private fun registerCore(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "$NAMESPACE/core")
            .setMethodCallHandler { call, result ->
                val core = TimeCoreHost.core(context)
                when (call.method) {
                    "snapshot" -> result.success(core.snapshot().toMap())
                    "configure" -> {
                        core.configure(
                            quizSec = call.argument<Number>("quizSeconds")
                                ?.toLong() ?: ScreenTimeCore.DEFAULT_QUIZ_SEC,
                            restSec = call.argument<Number>("restSeconds")
                                ?.toLong() ?: ScreenTimeCore.DEFAULT_REST_SEC,
                            dailyLimit = call.argument<Number>("dailyLimit")
                                ?.toInt() ?: ScreenTimeCore.DEFAULT_DAILY_LIMIT,
                        )
                        result.success(null)
                    }
                    "manualRest" -> {
                        TimeCoreHost.applyEffect(core.manualRest())
                        result.success(null)
                    }
                    "consumeExemption" -> {
                        TimeCoreHost.applyEffect(core.consumeExemption())
                        result.success(null)
                    }
                    "seedFromSnapshot" -> {
                        val seeded = core.seedFromSnapshot(
                            usedTodayMs = call.argument<Number>("usedTodaySec")
                                ?.toLong()?.times(1000) ?: 0L,
                            thresholdMs = call.argument<Number>("thresholdSec")
                                ?.toLong()?.times(1000) ?: 0L,
                            exemptionsUsed = call.argument<Number>("exemptionsUsed")
                                ?.toInt() ?: 0,
                            resting = call.argument<Boolean>("resting") ?: false,
                            restEndsAtMs = call.argument<Number>("restEndsAtMs")
                                ?.toLong() ?: 0L,
                        )
                        result.success(seeded)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerScreenEvents(engine: FlutterEngine, context: Context) {
        EventChannel(engine.dartExecutor.binaryMessenger, "$NAMESPACE/screen_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    ScreenEventBus.attach(events)
                    val powerManager =
                        context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    events.success(powerManager.isInteractive)
                }

                override fun onCancel(arguments: Any?) {
                    ScreenEventBus.detach()
                }
            })
    }

    private fun registerMonitor(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "$NAMESPACE/monitor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        ScreenMonitorService.start(context.applicationContext)
                        result.success(true)
                    }
                    "stopMonitoring" -> {
                        ScreenMonitorService.stop(context.applicationContext)
                        result.success(null)
                    }
                    "isMonitoring" -> result.success(monitoring)
                    "getPermissions" -> result.success(permissionStatus(context))
                    "openPermissionSettings" -> {
                        openPermissionSettings(context, call.argument<String>("kind"))
                        result.success(null)
                    }
                    "moveToBack" -> {
                        // 不 finish：仅把任务切到后台，缓存引擎/Dart isolate 继续运行。
                        val moved = ActivityTracker.currentActivity
                            ?.moveTaskToBack(true) ?: false
                        result.success(moved)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerIntervention(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "$NAMESPACE/intervention")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 到点干预：把 MainActivity 拉到前台 + 高优全屏通知兜底。
                    "request" -> {
                        requestIntervention(call.argument<String>("phase"))
                        result.success(null)
                    }
                    "dismiss" -> {
                        dismissIntervention()
                        result.success(null)
                    }

                    // 休息期自动熄屏（10 秒内未答题豁免时触发）。
                    "lockScreen" -> result.success(lockScreen())
                    "isDeviceAdminEnabled" -> result.success(isDeviceAdminEnabled())
                    "openDeviceAdminSettings" -> {
                        openDeviceAdminSettings()
                        result.success(null)
                    }

                    // 屏幕固定（休息期独占，防手动切任务）。
                    "startScreenPinning" -> result.success(startScreenPinning())
                    "stopScreenPinning" -> result.success(stopScreenPinning())

                    else -> result.notImplemented()
                }
            }
    }

    // -----------------------------------------------------------------
    // 到点干预：把界面拉到用户面前
    // -----------------------------------------------------------------

    /**
     * 到点干预：尽力把 [MainActivity] 拉到前台，并补一条全屏 intent 通知兜底。
     *
     * Android 10+ 限制后台启动 Activity，但持有 `SYSTEM_ALERT_WINDOW` 的应用
     * 属于官方豁免范围，因此悬浮窗权限是"自动切到休息页"的关键前提；
     * 未授权时退化为高优先级通知（锁屏/灭屏下可全屏展示，亮屏使用中为横幅）。
     */
    internal fun requestIntervention(phase: String?) {
        val app = ScreenMonitorApp.instance
        // 同步休息阶段给紧急退出控制器（密码通过后决定"退出"还是"改密"）。
        EmergencyKeyController.resting = phase == INTERVENTION_PHASE_RESTING
        val intent = Intent(app, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_INTERVENTION_PHASE, phase)
        }
        if (canStartActivityFromBackground(app)) {
            // 已有界面时 SINGLE_TOP 只触发 onNewIntent，不会重建 Activity。
            runCatching { app.startActivity(intent) }
        }
        // 悬浮层兜底（第 3 步）：若拉起失败（权限/ROM 限制）导致短延迟后
        // Activity 仍未到前台，且用户已授权悬浮窗，则全屏遮罩覆盖当前应用。
        // 已授权 canDrawOverlays 时 startActivity 本身就是官方豁免项；
        // 未授权则连遮罩也加不上，仅剩通知路径。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            Settings.canDrawOverlays(app)
        ) {
            InterventionOverlay.requestShow(app, phase)
        }
        showInterventionNotification(app, intent, phase)
    }

    /** 后台启动 Activity 是否被系统允许（悬浮窗权限是官方豁免项）。 */
    private fun canStartActivityFromBackground(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Settings.canDrawOverlays(context)

    /** 发送高优先级 + 全屏 intent 通知，锁屏/灭屏时可直接全屏展示。 */
    private fun showInterventionNotification(
        context: Context,
        contentIntent: Intent,
        phase: String?,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    ALERT_CHANNEL_ID,
                    "Rest reminders",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = "Full-screen rest reminder" },
            )
        }

        val pending = PendingIntent.getActivity(
            context,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                },
        )
        val isRest = phase == INTERVENTION_PHASE_RESTING

        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setContentTitle(if (isRest) "Time to rest" else "Quick check-in")
            .setContentText(
                if (isRest) "Take a short break now" else "Answer to continue",
            )
            .setSmallIcon(R.drawable.ic_screen_monitor)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .build()

        manager.notify(ALERT_NOTIFICATION_ID, notification)
    }

    /** 撤销干预：取消到点通知与悬浮层兜底。 */
    internal fun dismissIntervention() {
        // 回到计时阶段：紧急退出控制器恢复"主界面可改密"分流。
        EmergencyKeyController.resting = false
        dismissInterventionNotification()
    }

    /** 仅取消到点通知与悬浮层兜底（紧急退出休息时复用，不重复改 phase）。 */
    fun dismissInterventionNotification() {
        val manager = ScreenMonitorApp.instance
            .getSystemService(NotificationManager::class.java)
        manager.cancel(ALERT_NOTIFICATION_ID)
        InterventionOverlay.hide()
    }

    // -----------------------------------------------------------------
    // 权限状态查询与系统设置跳转
    // -----------------------------------------------------------------

    private fun permissionStatus(context: Context): Map<String, Boolean> {
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        val notificationsEnabled =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                notificationManager.areNotificationsEnabled()
            } else {
                true
            }
        val fullScreenIntentAllowed =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                notificationManager.canUseFullScreenIntent()
            } else {
                true
            }
        // 精确闹钟：Android 12+ 才需要 SCHEDULE_EXACT_ALARM（14+ 默认拒绝）；
        // 12 以下 setExact 无需权限，直接视为已授予。
        val exactAlarmAllowed =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                    .canScheduleExactAlarms()
            } else {
                true
            }

        return mapOf(
            "overlay" to Settings.canDrawOverlays(context),
            "ignoreBatteryOptimizations" to
                powerManager.isIgnoringBatteryOptimizations(context.packageName),
            "notifications" to notificationsEnabled,
            "fullScreenIntent" to fullScreenIntentAllowed,
            "accessibility" to isEmergencyKeyAccessibilityEnabled(context),
            "exactAlarm" to exactAlarmAllowed,
        )
    }

    /** 紧急按键监听的无障碍服务是否已被用户启用。 */
    private fun isEmergencyKeyAccessibilityEnabled(context: Context): Boolean {
        val expected = android.content.ComponentName(
            context,
            EmergencyKeyAccessibilityService::class.java,
        ).flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun openPermissionSettings(context: Context, kind: String?) {
        val packageName = context.packageName
        // 按优先级逐个尝试目标设置页：部分厂商 ROM 裁剪了系统页面，
        // 前一个抛 ActivityNotFoundException 时回退到下一个，最后兜底应用详情页。
        val attempts = when (kind) {
            "overlay" -> listOf(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            "ignoreBatteryOptimizations" -> listOf(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"),
                ),
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            )
            "notifications" -> listOf(notificationSettingsIntent(packageName))
            "accessibility" -> listOf(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            "exactAlarm" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    listOf(
                        Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                } else {
                    // Android 12 以下无需精确闹钟权限，跳应用详情页。
                    listOf(appDetailsIntent(packageName))
                }
            "fullScreenIntent" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    listOf(
                        Intent(
                            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                } else {
                    // Android 13 及以下全屏 intent 默认授予，无需专门页面。
                    listOf(notificationSettingsIntent(packageName))
                }
            "autoStart" -> {
                // 无公开 API：按厂商组件名尽力跳转自启动管理页，失败回退应用详情。
                tryOpenOemAutoStartPage(context)
                return
            }
            else -> listOf(appDetailsIntent(packageName))
        }
        for (intent in attempts) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: Exception) {
                // 尝试下一级回退
            }
        }
        runCatching {
            context.startActivity(
                appDetailsIntent(packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    /**
     * 尝试跳转各 OEM 的自启动管理页（无公开 API，按已知组件名逐一尝试）。
     * 全部失败时回退应用详情页。注意此处用 startActivity 试错而非
     * resolveActivity 预判——API 30+ 的包可见性过滤会让后者查不到其他应用。
     */
    private fun tryOpenOemAutoStartPage(context: Context) {
        val candidates = listOf(
            // MIUI
            "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
            // EMUI / HarmonyOS
            "com.huawei.systemmanager/com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            "com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            // ColorOS（OPPO/一加/realme）
            "com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oplus.battery/com.oplus.battery.startup.StartupAppListActivity",
            // OriginOS / FuntouchOS（vivo/iQOO）
            "com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            // Samsung
            "com.samsung.android.lool/com.samsung.android.sm.ui.ram.AutoRunActivity",
            // 联想 ZuxOS / Legacy
            "com.lenovo.security/com.lenovo.security.purviews.AutoStartActivity",
            "com.leb.secure/com.lenovo.leb.secure.purviews.AutoStartActivity",
        )
        for (candidate in candidates) {
            try {
                val intent = Intent().apply {
                    component = ComponentName.unflattenFromString(candidate)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                return
            } catch (_: Exception) {
                // 组件不存在或被 ROM 拒绝，尝试下一个
            }
        }
        runCatching {
            context.startActivity(
                appDetailsIntent(context.packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun notificationSettingsIntent(packageName: String): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            appDetailsIntent(packageName)
        }

    private fun appDetailsIntent(packageName: String): Intent =
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )

    // -----------------------------------------------------------------
    // Device Admin / lockNow（休息期自动熄屏）
    // -----------------------------------------------------------------

    private fun isDeviceAdminEnabled(): Boolean {
        val app = ScreenMonitorApp.instance
        val dpm = app.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(app, ScreenMonitorDeviceAdmin::class.java)
        return dpm.isAdminActive(admin)
    }

    /** 跳转到系统 Device Admin 授权页，让用户一次性授权 force-lock 策略。 */
    private fun openDeviceAdminSettings() {
        val app = ScreenMonitorApp.instance
        // createAddAdminActiveIntent 是 @hide API（Android 12+ 不可直接调用），
        // 通过反射尝试；失败则回退到安全设置页让用户手动查找 Device Admin 入口。
        val dpm = app.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(app, ScreenMonitorDeviceAdmin::class.java)
        try {
            val method = DevicePolicyManager::class.java.getDeclaredMethod(
                "createAddAdminActiveIntent",
                ComponentName::class.java,
                CharSequence::class.java,
            )
            val intent = method.invoke(dpm, admin,
                "Screen Time Manager needs this to auto-lock the screen during rest.") as Intent
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            app.startActivity(intent)
        } catch (_: Exception) {
            val fallback = Intent(Settings.ACTION_SECURITY_SETTINGS)
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            app.startActivity(fallback)
        }
    }

    /**
     * 调用 DevicePolicyManager.lockNow() 熄屏。
     *
     * 休息期 10 秒无操作自动熄屏时调用：先临时解除 [RestGuard] 武装，
     * 避免锁屏后 Activity 进入 onStop 被误判为"用户强行切走"；
     * 锁屏完成后重新武装（若仍在休息阶段，Dart 侧会重新 startScreenPinning）。
     *
     * @return true 表示成功熄屏；false 表示未授权 Device Admin 或调用失败。
     */
    private fun lockScreen(): Boolean {
        if (!isDeviceAdminEnabled()) return false
        val app = ScreenMonitorApp.instance
        val dpm = app.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        // 临时解除武装，防止 lockNow 导致 onStop 被 RestGuard 误判为强行切走
        val wasArmed = RestGuard.armed
        if (wasArmed) RestGuard.disarm()
        return try {
            dpm.lockNow()
            true
        } catch (_: SecurityException) {
            false
        } finally {
            if (wasArmed) RestGuard.arm()
        }
    }

    // -----------------------------------------------------------------
    // 屏幕固定（Activity.startLockTask / stopLockTask）
    // -----------------------------------------------------------------

    /**
     * 进入屏幕固定模式：用户无法手动切任务/拉通知栏。
     *
     * 非 Device Owner 调用会弹系统确认对话框（"固定此应用？"），用户
     * 确认后进入固定模式。
     */
    internal fun startScreenPinning(): Boolean {
        // 无论 Activity 当前是否在前台都先武装守卫：若此刻不在前台
        // （例如到点干预正在把界面拉回来），MainActivity 恢复后其轮询
        // 会依据 armed 状态自动补上固定。
        RestGuard.arm()
        val activity = ActivityTracker.currentActivity ?: return false
        return try {
            activity.startLockTask()
            true
        } catch (_: IllegalStateException) {
            // 暂不能固定（如 Activity 未在前台），保持武装等待轮询重试。
            false
        }
    }

    /** 退出屏幕固定模式（休息结束/豁免通过）。 */
    internal fun stopScreenPinning(): Boolean {
        // 必须先解除武装：stopLockTask 会触发 onLockTaskModeExiting 回调，
        // 若守卫仍处于 armed 状态会立刻重新固定，导致休息结束也退不出来。
        RestGuard.disarm()
        val activity = ActivityTracker.currentActivity ?: return false
        return try {
            activity.stopLockTask()
            true
        } catch (_: IllegalStateException) {
            false
        }
    }
}
