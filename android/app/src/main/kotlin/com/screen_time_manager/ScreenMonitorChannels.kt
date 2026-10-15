package com.screen_time_manager

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
 * - `intervention`：请求 / 撤销到点干预（高优通知 + full-screen intent /
 *   悬浮窗待第 3 步实现）；休息期自动熄屏（DevicePolicyManager.lockNow）
 *   与屏幕固定（startLockTask / stopLockTask）。
 */
object ScreenMonitorChannels {
    private const val NAMESPACE = "com.screen_time_manager/platform"

    /** 监控是否运行（以前台服务存活为准）。 */
    val monitoring: Boolean
        get() = ScreenMonitorService.running

    /** 在给定引擎上注册全部平台通道。 */
    fun register(engine: FlutterEngine, context: Context) {
        registerScreenEvents(engine, context)
        registerMonitor(engine, context)
        registerIntervention(engine)
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
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerIntervention(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "$NAMESPACE/intervention")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // TODO(第3步): request → 高优通知 + setFullScreenIntent / 悬浮窗；
                    // dismiss → 取消通知与悬浮层。
                    "request", "dismiss" -> result.success(null)

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

        return mapOf(
            "overlay" to Settings.canDrawOverlays(context),
            "ignoreBatteryOptimizations" to
                powerManager.isIgnoringBatteryOptimizations(context.packageName),
            "notifications" to notificationsEnabled,
            "fullScreenIntent" to fullScreenIntentAllowed,
        )
    }

    private fun openPermissionSettings(context: Context, kind: String?) {
        val packageName = context.packageName
        val intent = when (kind) {
            "overlay" -> Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            "ignoreBatteryOptimizations" -> Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"),
            )
            "notifications" -> notificationSettingsIntent(packageName)
            "fullScreenIntent" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName"),
                    )
                } else {
                    appDetailsIntent(packageName)
                }
            else -> appDetailsIntent(packageName)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            context.startActivity(
                appDetailsIntent(packageName)
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
     * @return true 表示成功熄屏；false 表示未授权 Device Admin 或调用失败。
     */
    private fun lockScreen(): Boolean {
        if (!isDeviceAdminEnabled()) return false
        val app = ScreenMonitorApp.instance
        val dpm = app.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return try {
            dpm.lockNow()
            true
        } catch (_: SecurityException) {
            false
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
    private fun startScreenPinning(): Boolean {
        val activity = ActivityTracker.currentActivity ?: return false
        return try {
            // 先武装守卫：用户退出固定/强行切走时会被拉回或熄屏。
            RestGuard.arm()
            activity.startLockTask()
            true
        } catch (_: IllegalStateException) {
            RestGuard.disarm()
            false
        }
    }

    /** 退出屏幕固定模式（休息结束/豁免通过）。 */
    private fun stopScreenPinning(): Boolean {
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
