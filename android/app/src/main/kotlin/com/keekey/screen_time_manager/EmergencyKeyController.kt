package com.keekey.screen_time_manager

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import android.view.KeyEvent
import android.widget.Toast

/**
 * 物理按键紧急退出 / 改密控制器（多事件源 + debounce）。
 *
 * 为什么多事件源：OEM ROM（ZuxOS、MIUI、ColorOS 等）普遍在系统层拦截音量键——
 * PhoneWindowManager.interceptKeyBeforeQueueing 里就消费掉，早于无障碍服务
 * 和 Activity 的事件管线。单独依赖无障碍或 dispatchKeyEvent 在部分设备上会
 * 完全收不到音量键。三层通路并行、内部 debounce 去重，才是可靠做法：
 *
 *   Activity.dispatchKeyEvent  ← 主路径：应用前台/屏幕固定期间，系统调音量之前
 *   ContentObserver 音量变化  ← 兜底  ：完全独立，不依赖任何窗口/无障碍
 *   无障碍服务 onKeyEvent     ← 第三层：少数 ROM 上可能仍可达
 *
 * 交互流程：
 * 1. 快速交替按 音量"+"→音量"-"→音量"+"（相邻间隔 ≤ [SEQUENCE_GAP_MS]）进入
 *    10 秒密码检测态；第三击被吞掉，净音量变化为 0。
 * 2. 默认密码 音量"-"×5（可改，存 SharedPreferences）：
 *    - resting 阶段 → disarm + stopLockTask + HOME，紧急退出；
 *    - 应用主界面 → 进入改密态，10 秒内录 5 个音量键序列为新密码；
 *    - 错误/超时 → 静默忽略。
 *
 * 密码窗口内 [capturingVolumeKeys] == true：无障碍服务吞掉音量键；Activity
 * dispatchKeyEvent 返回 true 抑制系统处理；ContentObserver 在 arm 时把音量
 * 预调到中间档，防止在 0 / max 档按同方向不产生变化事件。
 */
object EmergencyKeyController {

    private const val TAG = "EmergencyKeyController"

    /** 密码 / 新密码的按键个数。 */
    private const val PASSWORD_LENGTH = 5

    /** 触发序列相邻两击的最大间隔。 */
    private const val SEQUENCE_GAP_MS = 800L

    /** 密码输入与新密码录入的有效时长（超时回到 IDLE，可重新用交替序列触发）。 */
    private const val INPUT_WINDOW_MS = 5_000L

    /** 两个事件源同时上报的去重窗口（同方向视为同一次按键）。 */
    private const val DEBOUNCE_MS = 60L

    private const val PREFS_NAME = "emergency_keys"
    private const val PREF_PASSWORD = "password_keycodes"

    private val handler = Handler(Looper.getMainLooper())

    private var state: State = State.IDLE

    // 触发序列检测（仅 IDLE 态使用）。
    private var prevKey = 0
    private var prevAt = 0L
    private var lastKey = 0
    private var lastAt = 0L

    private val entries = ArrayList<Int>()

    private val timeoutRunnable = Runnable { resetToIdle() }

    /** 上一次处理过的音量方向与时间戳，用于多源 debounce。 */
    private var lastProcessedDir: Boolean? = null
    private var lastProcessedAt = 0L

    /** 当前是否处于休息阶段，由 intervention 通道同步。 */
    @Volatile
    var resting: Boolean = false

    /** 是否处于密码录入窗口（无障碍/Activity 据此吞掉音量键）。 */
    val capturingVolumeKeys: Boolean
        get() = state != State.IDLE

    private enum class State {
        IDLE,           // 监听触发序列
        ARMED,          // 等待 5 键密码
        RECORDING_NEW_PASSWORD, // 录新密码
    }

    // -----------------------------------------------------------------
    // 事件入口（三个通路）
    // -----------------------------------------------------------------

    /**
     * 通路 1 / 3：直接按键 DOWN（来自 Activity.dispatchKeyEvent 或无障碍服务）。
     * 返回 true 表示吞掉事件（抑制调音量和 HUD）；
     * 空闲态下仅触发序列第三击返回 true（净音量变化为 0）。
     */
    fun onKeyDown(keyCode: Int): Boolean {
        val isVolUp = keyCode == KeyEvent.KEYCODE_VOLUME_UP
        val isVolDown = keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (!isVolUp && !isVolDown) return false
        return handleDirection(isVolUp, source = "keyEvent")
    }

    /**
     * 通路 2：ContentObserver 观察到音量变化（方向由 diff 判定）。
     * 完全独立，不依赖窗口或无障碍。
     */
    fun onVolumeChanged(isUp: Boolean) {
        handleDirection(isUp, source = "contentObserver")
    }

    /** 统一处理一个音量方向事件（内含 debounce）。 */
    private fun handleDirection(isUp: Boolean, source: String): Boolean {
        val now = System.currentTimeMillis()
        // debounce：60ms 内同方向视为同一次按键（Activity 和 Observer 可能同时上报）。
        if (isUp == lastProcessedDir && now - lastProcessedAt < DEBOUNCE_MS) {
            Log.d(TAG, "debounce skip (src=$source, up=$isUp)")
            return false
        }
        lastProcessedDir = isUp
        lastProcessedAt = now
        val keyCode = if (isUp) KeyEvent.KEYCODE_VOLUME_UP else KeyEvent.KEYCODE_VOLUME_DOWN
        Log.d(TAG, "direction up=$isUp src=$source state=$state")

        return when (state) {
            State.IDLE -> handleIdle(keyCode)
            State.ARMED -> {
                handlePasswordEntry(keyCode)
                true // 密码窗口内吞掉所有音量键
            }
            State.RECORDING_NEW_PASSWORD -> {
                handleNewPasswordEntry(keyCode)
                true
            }
        }
    }

    // -----------------------------------------------------------------
    // 各状态处理
    // -----------------------------------------------------------------

    /**
     * 空闲态：检测 音量+→音量-→音量+ 交替序列（相邻 ≤ [SEQUENCE_GAP_MS]）。
     * 非音量键忽略且不打断序列；同侧连按是正常调音量，不构成交替模式。
     */
    private fun handleIdle(keyCode: Int): Boolean {
        val now = System.currentTimeMillis()
        val matched = prevKey == KeyEvent.KEYCODE_VOLUME_UP &&
            lastKey == KeyEvent.KEYCODE_VOLUME_DOWN &&
            keyCode == KeyEvent.KEYCODE_VOLUME_UP &&
            lastAt - prevAt <= SEQUENCE_GAP_MS &&
            now - lastAt <= SEQUENCE_GAP_MS
        if (matched) {
            Log.d(TAG, "trigger sequence matched")
            prevKey = 0
            lastKey = 0
            armPasswordEntry()
            return true // 吞掉第三击 → 净音量变化为 0
        }
        prevKey = lastKey
        prevAt = lastAt
        lastKey = keyCode
        lastAt = now
        return false
    }

    private fun handlePasswordEntry(keyCode: Int) {
        entries.add(keyCode)
        if (entries.size >= PASSWORD_LENGTH) {
            handler.removeCallbacks(timeoutRunnable)
            if (matchesPassword(entries)) {
                Log.d(TAG, "password correct")
                onPasswordCorrect()
            } else {
                Log.d(TAG, "password wrong")
                resetToIdle()
            }
        }
    }

    private fun handleNewPasswordEntry(keyCode: Int) {
        entries.add(keyCode)
        if (entries.size >= PASSWORD_LENGTH) {
            handler.removeCallbacks(timeoutRunnable)
            savePassword(entries.toIntArray())
            toast("New password saved")
            Log.d(TAG, "new password saved")
            resetToIdle()
        }
    }

    // -----------------------------------------------------------------
    // 状态切换
    // -----------------------------------------------------------------

    private fun armPasswordEntry() {
        state = State.ARMED
        entries.clear()
        toast("Emergency unlock: enter 5-key password")
        restartTimeout()
    }

    private fun onPasswordCorrect() {
        if (resting) {
            exitRestImmediately()
            resetToIdle()
            return
        }
        if (!ActivityTracker.isResumed) {
            resetToIdle()
            return
        }
        state = State.RECORDING_NEW_PASSWORD
        entries.clear()
        toast("Press 5 volume keys as the new password (5s)")
        restartTimeout()
    }

    /**
     * 紧急退出休息：彻底关闭应用。
     *
     * 设计目标：紧急退出后应用必须**真正退出/关闭**，而不是仅仅切回桌面。
     * 只发 HOME 的话，缓存的 FlutterEngine 仍在跑、状态机继续 tick、休息页
     * 依然活着，后续到点干预还会把界面重新拉回休息页，休息计时与状态都不再可靠。
     *
     * 步骤（顺序关键）：
     * 1. 解除 [RestGuard] 并退出屏幕固定（铁律：先 disarm 再 stopLockTask）；
     * 2. 停止前台服务，切断亮灭屏广播，避免退出过程中仍有事件喂给状态机；
     * 3. 取消到点干预通知；
     * 4. 结束 Activity 并从最近任务中移除；
     * 5. 延迟一拍后杀掉本进程——同时销毁缓存 FlutterEngine 与 Dart isolate，
     *    保证没有残留 tick、也不会被后续干预拉回重启。
     *
     * 已完成的会话记录在阶段切换时已落库；本条被中断的 rest_session 不记录
     * （与 AGENTS 的"被杀后重置为 tracking"健壮性约定一致）。
     */
    private fun exitRestImmediately() {
        Log.d(TAG, "emergency exit: shutting down app")
        val app = ScreenMonitorApp.instance

        // 抑制 onTaskRemoved 的自动重启闹钟：finishAndRemoveTask 会触发
        // onTaskRemoved，若不抑制，应用会在退出 1 秒后被闹钟重新拉起。
        ScreenMonitorService.suppressAutoRestart = true

        RestGuard.disarm()
        runCatching { ActivityTracker.currentActivity?.stopLockTask() }
        ScreenMonitorService.stop(app)
        ScreenMonitorChannels.dismissInterventionNotification()
        resting = false

        val activity = ActivityTracker.currentActivity
        runCatching { activity?.finishAndRemoveTask() }
        runCatching { activity?.finishAffinity() }
        toast("Exiting")

        // 稍等一拍让 finish / 服务停止生效，再杀进程完成真正的"应用退出"。
        handler.postDelayed({
            Log.d(TAG, "emergency exit: killing process")
            Process.killProcess(Process.myPid())
        }, 400L)
    }

    private fun restartTimeout() {
        handler.removeCallbacks(timeoutRunnable)
        handler.postDelayed(timeoutRunnable, INPUT_WINDOW_MS)
    }

    private fun resetToIdle() {
        handler.removeCallbacks(timeoutRunnable)
        entries.clear()
        prevKey = 0
        lastKey = 0
        lastProcessedDir = null
        state = State.IDLE
    }

    // -----------------------------------------------------------------
    // 密码持久化
    // -----------------------------------------------------------------

    /** 默认密码：音量"-" ×5。 */
    private fun defaultPassword(): IntArray =
        IntArray(PASSWORD_LENGTH) { KeyEvent.KEYCODE_VOLUME_DOWN }

    private fun prefs(app: Context) =
        app.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun loadPassword(): IntArray {
        val app = ScreenMonitorApp.instance
        val raw = prefs(app).getString(PREF_PASSWORD, null) ?: return defaultPassword()
        val codes = raw.split(",").mapNotNull { it.trim().toIntOrNull() }
        return if (codes.size == PASSWORD_LENGTH) codes.toIntArray() else defaultPassword()
    }

    private fun savePassword(codes: IntArray) {
        val app = ScreenMonitorApp.instance
        prefs(app).edit()
            .putString(PREF_PASSWORD, codes.joinToString(","))
            .apply()
    }

    private fun matchesPassword(input: List<Int>): Boolean =
        input.toIntArray().contentEquals(loadPassword())

    private fun toast(text: String) {
        handler.post {
            Toast.makeText(ScreenMonitorApp.instance, text, Toast.LENGTH_SHORT).show()
        }
    }
}
