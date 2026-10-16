package com.screen_time_manager

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.widget.Toast

/**
 * 物理按键紧急退出 / 改密控制器。
 *
 * 交互流程：
 * 1. 同时按住 **电源键 + 音量"+"**（两键 DOWN 间隔不超过 [COMBO_WINDOW_MS]）
 *    进入密码检测态，10 秒内有效；
 * 2. 默认密码为 **连按 5 次音量"-"**（可改，持久化在 SharedPreferences）；
 *    - 当前处于休息阶段（[resting] == true）：解除屏幕固定并退回桌面，紧急退出；
 *    - 当前停留在应用主界面（非休息且 Activity 在前台）：进入改密态，
 *      10 秒内连按 5 个音量键（音量"+"/"-"任意序列）作为新密码；
 * 3. 其它无效输入与超时一律静默忽略，回到空闲态。
 *
 * 重要前提：普通应用无法收到电源键事件（系统在事件到达应用前拦截），
 * 因此本控制器的按键全部来自 [EmergencyKeyAccessibilityService]
 * （用户需在系统无障碍设置中一次性授权）。音量键同理由无障碍服务统一上报，
 * 保证在屏幕固定 / Kiosk 期间也能收到。
 *
 * 所有回调都在主线程（无障碍 onKeyEvent 即主线程），状态无需额外加锁。
 */
object EmergencyKeyController {

    /** 密码 / 新密码的按键个数。 */
    private const val PASSWORD_LENGTH = 5

    /** 电源键与音量"+"被视为"同时按下"的最大间隔。 */
    private const val COMBO_WINDOW_MS = 600L

    /** 密码输入与新密码录入的有效时长。 */
    private const val INPUT_WINDOW_MS = 10_000L

    private const val PREFS_NAME = "emergency_keys"
    private const val PREF_PASSWORD = "password_keycodes"

    private val handler = Handler(Looper.getMainLooper())

    private var state: State = State.IDLE
    private var lastPowerDownAt = 0L
    private var lastVolUpDownAt = 0L

    /** 密码输入/改密过程中已记录的音量键序列。 */
    private val entries = ArrayList<Int>()

    private val timeoutRunnable = Runnable { resetToIdle() }

    /**
     * 当前是否处于休息阶段。由 intervention 通道的 request/dismiss 维护，
     * 决定密码验证通过后是"紧急退出"还是"允许改密"。
     */
    @Volatile
    var resting: Boolean = false

    private enum class State {
        /** 空闲：仅监听电源 + 音量"+"组合键。 */
        IDLE,

        /** 组合键已触发：等待输入 5 键密码。 */
        ARMED,

        /** 主界面密码正确：等待录入 5 个新按键作为新密码。 */
        RECORDING_NEW_PASSWORD,
    }

    /**
     * 接收一个按键 DOWN 事件（长按重复事件由调用方过滤 repeatCount > 0）。
     *
     * @return 始终返回 false：本控制器只观测、不吞键，音量键原有功能不受影响。
     */
    fun onKeyDown(keyCode: Int): Boolean {
        when (state) {
            State.IDLE -> handleIdle(keyCode)
            State.ARMED -> handlePasswordEntry(keyCode)
            State.RECORDING_NEW_PASSWORD -> handleNewPasswordEntry(keyCode)
        }
        return false
    }

    // -----------------------------------------------------------------
    // 各状态处理
    // -----------------------------------------------------------------

    private fun handleIdle(keyCode: Int) {
        val now = System.currentTimeMillis()
        when (keyCode) {
            KeyEvent.KEYCODE_POWER -> lastPowerDownAt = now
            KeyEvent.KEYCODE_VOLUME_UP -> lastVolUpDownAt = now
            else -> return
        }
        // 两键在时间窗内先后出现即视为"同时按住"。
        if (lastPowerDownAt != 0L && lastVolUpDownAt != 0L &&
            kotlin.math.abs(lastPowerDownAt - lastVolUpDownAt) <= COMBO_WINDOW_MS
        ) {
            armPasswordEntry()
        }
    }

    private fun handlePasswordEntry(keyCode: Int) {
        // 密码为 5 个音量键序列（默认全是音量"-"）；电源键等其它输入忽略，
        // 不重置倒计时，超时后静默失败。
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP &&
            keyCode != KeyEvent.KEYCODE_VOLUME_DOWN
        ) {
            return
        }
        entries.add(keyCode)
        if (entries.size >= PASSWORD_LENGTH) {
            handler.removeCallbacks(timeoutRunnable)
            if (matchesPassword(entries)) {
                onPasswordCorrect()
            } else {
                // 密码错误：不提示、不重试，静默回到空闲态。
                resetToIdle()
            }
        }
    }

    private fun handleNewPasswordEntry(keyCode: Int) {
        // 新密码可由音量"+"/"-"任意序列组成；电源键不录入（会触发灭屏/电源菜单）。
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP &&
            keyCode != KeyEvent.KEYCODE_VOLUME_DOWN
        ) {
            return
        }
        entries.add(keyCode)
        if (entries.size >= PASSWORD_LENGTH) {
            handler.removeCallbacks(timeoutRunnable)
            savePassword(entries.toIntArray())
            toast("New password saved")
            resetToIdle()
        }
    }

    // -----------------------------------------------------------------
    // 状态切换
    // -----------------------------------------------------------------

    private fun armPasswordEntry() {
        state = State.ARMED
        entries.clear()
        lastPowerDownAt = 0L
        lastVolUpDownAt = 0L
        toast("Emergency unlock: press Volume Down 5 times")
        restartTimeout()
    }

    /**
     * 密码验证通过后的分流。
     *
     * 休息期：解除 [RestGuard] + 退出屏幕固定 + 回桌面，完成紧急退出。
     * 主界面：进入改密态。非主界面（应用在后台等）一律忽略。
     */
    private fun onPasswordCorrect() {
        if (resting) {
            exitRestImmediately()
            resetToIdle()
            return
        }
        if (!ActivityTracker.isResumed) {
            // 不在应用主界面：不允许改密，静默忽略。
            resetToIdle()
            return
        }
        state = State.RECORDING_NEW_PASSWORD
        entries.clear()
        toast("Press 5 volume keys as the new password (10s)")
        restartTimeout()
    }

    /** 紧急退出休息：解除固定并退回桌面。 */
    private fun exitRestImmediately() {
        // 先解除武装，避免 stopLockTask / 退后台触发 RestGuard 立刻拉回。
        RestGuard.disarm()
        runCatching { ActivityTracker.currentActivity?.stopLockTask() }
        ScreenMonitorChannels.dismissInterventionNotification()

        val app = ScreenMonitorApp.instance
        // stopLockTask 生效需要一个节拍，延迟发送 HOME 更稳妥。
        handler.postDelayed({
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            runCatching { app.startActivity(home) }
        }, 300L)
        toast("Exiting rest")
    }

    private fun restartTimeout() {
        handler.removeCallbacks(timeoutRunnable)
        handler.postDelayed(timeoutRunnable, INPUT_WINDOW_MS)
    }

    /** 超时 / 完成：静默回到空闲态（不打扰用户）。 */
    private fun resetToIdle() {
        handler.removeCallbacks(timeoutRunnable)
        entries.clear()
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

    /** 输入序列与已存密码比较（长度由状态机保证为 5）。 */
    private fun matchesPassword(input: List<Int>): Boolean =
        input.toIntArray().contentEquals(loadPassword())

    private fun toast(text: String) {
        handler.post {
            Toast.makeText(ScreenMonitorApp.instance, text, Toast.LENGTH_SHORT).show()
        }
    }
}
