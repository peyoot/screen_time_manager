package com.screen_time_manager

import android.app.NotificationManager
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
 * - `intervention`：本步仅应答成功；高优通知 / full-screen intent / 悬浮窗
 *   在第 3 步实现。原生侧后续会自行判断 App 是否已在前台。
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
                    // 订阅建立时先推当前屏幕状态，避免冷启动阶段状态未知。
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
                    else -> result.notImplemented()
                }
            }
    }

    /** 查询监控所需的各项权限授予状态（key 与 Dart MonitorPermission 枚举对应）。 */
    private fun permissionStatus(context: Context): Map<String, Boolean> {
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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

    /** 跳转到指定权限对应的系统设置页；找不到对应页面时回退到应用详情页。 */
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
            // 部分 ROM 裁剪了对应设置页，回退到应用详情页。
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
}
