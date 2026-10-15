package com.screen_time_manager

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Application 入口。
 *
 * 进程启动时预创建一个常驻 [FlutterEngine] 并放入 [FlutterEngineCache]：
 * - MainActivity 通过 [ENGINE_ID] 复用同一引擎，Activity 销毁不影响引擎；
 * - 前台服务保活期间，引擎内的 Dart isolate 持续运行（状态机每秒 tick、
 *   亮灭屏事件经 EventChannel 到达），无界面时不渲染帧但逻辑不停。
 *
 * 平台通道在引擎执行 Dart 入口前注册完毕，保证 main() 中的
 * startMonitoring / 事件订阅调用一定有原生侧应答。
 */
class ScreenMonitorApp : Application() {

    companion object {
        @Volatile
        private var _instance: ScreenMonitorApp? = null

        /** 进程内单例引用，供 DevicePolicyManager 等需要
         *  Application context 的静态方法使用。 */
        val instance: ScreenMonitorApp
            get() = _instance
                ?: throw IllegalStateException(
                    "ScreenMonitorApp.onCreate() not called",
                )

        /** 缓存引擎的固定 ID，MainActivity 与潜在的后台入口均以此取用。 */
        const val ENGINE_ID = "screen_monitor_engine"
    }

    override fun onCreate() {
        super.onCreate()
        _instance = this

        // 休息期"不可退出"守卫：仅 resting 阶段武装（由 startScreenPinning 触发）。
        RestGuard.register(this)
        // 若设备已通过 ADB 把本应用设为 Device Owner，则加入 LockTask 白名单，
        // startLockTask() 将进入无退出手势的 Kiosk（LOCKED）模式。
        RestGuard.enableLockTaskForDeviceOwner(this)

        val engine = FlutterEngine(this)
        ScreenMonitorChannels.register(engine, applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
