package com.keekey.screen_time_manager

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import java.time.LocalDate

/**
 * 原生计时核心宿主。
 *
 * 作为 [ScreenTimeCore] 的进程内单例，同时被两处使用：
 * - [ScreenMonitorService]：每秒 `tick()` 推进计时，并在屏幕事件时喂入亮灭屏；
 * - `<ns>/core` 通道（[ScreenMonitorChannels]）：Dart 侧读取 [ScreenTimeCore.snapshot]
 *   与回写用户操作（手动休息 / 休息期豁免 / 配置）。
 *
 * 核心状态持久化在 SharedPreferences，故后台拉起进程（服务启动、Dart 未运行）时
 * 也能读取到历史状态与配置。
 */
object TimeCoreHost {

    private const val PREFS_NAME = "screen_time_core"

    @Volatile
    private var instance: ScreenTimeCore? = null

    /** 取（惰性创建）进程内共用的计时核心。 */
    fun core(context: Context): ScreenTimeCore {
        instance?.let { return it }
        synchronized(this) {
            instance?.let { return it }
            val appContext = context.applicationContext
            val store = PrefsCoreStore(
                appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE),
            )
            val created = ScreenTimeCore(SystemCoreClock(), store)
            instance = created
            return created
        }
    }

    /** 执行计时核心状态转移对应的副作用（全屏干预 + 屏幕固定）。 */
    fun applyEffect(effect: CoreEffect) {
        when (effect) {
            CoreEffect.ENTER_REST -> {
                // 到点直接把休息页拉到前台并武装屏幕固定（不再立即熄屏）。
                // 休息页展示后 10 秒内无答题豁免操作，由 Dart 侧经
                // intervention.lockScreen 熄屏（Device Admin）；用户之后
                // 重新亮屏由亮屏接收器补发干预，但不再熄屏，休息页常亮当秒表。
                ScreenMonitorChannels.requestIntervention("resting")
                ScreenMonitorChannels.startScreenPinning()
            }
            CoreEffect.EXIT_REST -> {
                ScreenMonitorChannels.dismissIntervention()
                ScreenMonitorChannels.stopScreenPinning()
            }
            CoreEffect.NONE -> Unit
        }
    }
}

/** 基于 SharedPreferences 的核心状态存储。 */
private class PrefsCoreStore(private val prefs: SharedPreferences) : CoreStore {

    override fun getLong(key: String, def: Long): Long = prefs.getLong(key, def)

    override fun getInt(key: String, def: Int): Int = prefs.getInt(key, def)

    override fun getString(key: String, def: String?): String? = prefs.getString(key, def)

    override fun getBoolean(key: String, def: Boolean): Boolean = prefs.getBoolean(key, def)

    override fun put(values: Map<String, Any>) {
        val editor = prefs.edit()
        values.forEach { (key, value) ->
            when (value) {
                is Long -> editor.putLong(key, value)
                is Int -> editor.putInt(key, value)
                is Boolean -> editor.putBoolean(key, value)
                is String -> editor.putString(key, value)
            }
        }
        editor.apply()
    }
}

/** 系统时钟实现。 */
private class SystemCoreClock : CoreClock {

    override fun wallMs(): Long = System.currentTimeMillis()

    override fun realtimeMs(): Long = SystemClock.elapsedRealtime()

    override fun dayKey(): String {
        val now = LocalDate.now()
        return String.format("%04d-%02d-%02d", now.year, now.monthValue, now.dayOfMonth)
    }
}
