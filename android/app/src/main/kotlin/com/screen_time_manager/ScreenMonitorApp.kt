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
    override fun onCreate() {
        super.onCreate()

        val engine = FlutterEngine(this)
        ScreenMonitorChannels.register(engine, applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        /** 缓存引擎的固定 ID，MainActivity 与潜在的后台入口均以此取用。 */
        const val ENGINE_ID = "screen_monitor_engine"
    }
}
