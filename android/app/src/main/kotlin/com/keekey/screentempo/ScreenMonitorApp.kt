package com.keekey.screen_time_manager

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Application 入口。
 *
 * 进程启动时预创建一个常驻 [FlutterEngine] 并放入 [FlutterEngineCache]：
 * - MainActivity 通过 [ENGINE_ID] 复用同一引擎，Activity 销毁不影响引擎；
 * - 用户打开过应用后，Activity 被销毁/退后台时引擎内的 Dart isolate 仍持续
 *   运行（状态机每秒 tick、亮灭屏事件经 EventChannel 到达）。
 *
 * **Dart 入口不在此执行（关键）**：开机广播 / 划卡闹钟会在"无任何 Activity"
 * 的后台拉起本进程，若此时就 executeDartEntrypoint 跑 main()+runApp()，
 * 引擎会在没有 FlutterView 可附着的上下文中进入不可渲染状态；用户随后点图标
 * 挂载 MainActivity 时只能看到黑屏，必须去系统设置强制停止进程才能恢复
 * （ZUXOS 真机复现）。因此这里只准备引擎壳与通道，Dart 入口改由
 * [MainActivity] 在窗口就绪后触发——后台进程不跑 Dart，前台打开时才启动 UI。
 *
 * 平台通道在引擎创建时注册完毕，保证 Dart 启动后 startMonitoring / 事件订阅
 * 调用一定有原生侧应答。
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
        // 注意：此处**不**调用 executeDartEntrypoint，Dart 入口由 MainActivity
        // 在窗口就绪后触发（见类注释）。后台拉起进程时引擎只作为空壳存在，
        // 不跑 Dart、不渲染，因此不会进入不可渲染状态。
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
