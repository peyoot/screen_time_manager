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
 * 1. 快速交替按 **音量"+" → 音量"-" → 音量"+"**（相邻两击间隔 ≤ [SEQUENCE_GAP_MS]）
 *    进入密码检测态，10 秒内有效。选此序列是因为其它组合均有系统级冲突：
 *    电源+音量键被截图/录屏/SOS 等 OEM 手势占用；双音量键长按与系统无障碍
 *    快捷键（TalkBack）冲突；交替音量序列无任何系统手势使用，全 ROM 通用。
 *    触发序列的第三击被吞掉，与第一击正负相抵——触发本身不改变音量。
 * 2. 默认密码为 **连按 5 次音量"-"**（可改，持久化在 SharedPreferences）：
 *    - 休息阶段（[resting] == true）：解除屏幕固定并退回桌面，紧急退出；
 *    - 应用主界面（非休息且 Activity 在前台）：进入改密态，10 秒内连按 5 个
 *      音量键（音量"+"/"-"任意序列）作为新密码；
 * 3. 其它无效输入与超时一律静默忽略，回到空闲态。
 *
 * 密码录入窗口内音量键被无障碍服务整体吞掉（音量不变、面板自动消隐）；
 * 空闲时音量键全部放行，正常调音量不受影响。
 *
 * 按键来源：[EmergencyKeyAccessibilityService]。屏幕固定 / Kiosk 期间无障碍
 * 服务依然收得到事件，且能在系统调音量之前吞掉事件（Activity 层做不到这点）。
 */
object EmergencyKeyController {

    /** 密码 / 新密码的按键个数。 */
    private const val PASSWORD_LENGTH = 5

    /** 触发序列相邻两击的最大间隔。 */
    private const val SEQUENCE_GAP_MS = 800L

    /** 密码输入与新密码录入的有效时长。 */
    private const val INPUT_WINDOW_MS = 10_000L

    private const val PREFS_NAME = "emergency_keys"
    private const val PREF_PASSWORD = "password_keycodes"

    private val handler = Handler(Looper.getMainLooper())

    private var state: State = State.IDLE

    // 触发序列检测（仅 IDLE 态使用）：最近两次音量键及时间。
    private var prevKey = 0
    private var prevAt = 0L
    private var lastKey = 0
    private var lastAt = 0L

    /** 密码输入/改密过程中已记录的音量键序列。 */
    private val entries = ArrayList<Int>()

    private val timeoutRunnable = Runnable { resetToIdle() }

    /**
     * 当前是否处于休息阶段。由 intervention 通道的 request/dismiss 维护，
     * 决定密码验证通过后是"紧急退出"还是"允许改密"。
     */
    @Volatile
    var resting: Boolean = false

    /** 是否处于密码录入窗口（无障碍服务据此吞掉音量键，含长按重复与抬起）。 */
    val capturingVolumeKeys: Boolean
        get() = state != State.IDLE

    private enum class State {
        /** 空闲：仅监听音量键交替触发序列。 */
        IDLE,

        /** 触发序列已识别：等待输入 5 键密码。 */
        ARMED,

        /** 主界面密码正确：等待录入 5 个新按键作为新密码。 */
        RECORDING_NEW_PASSWORD,
    }

    /**
     * 接收一个按键 DOWN 事件（长按重复事件由调用方过滤 repeatCount > 0）。
     *
     * @return true 表示吞掉该事件（系统不再调音量）；空闲态除触发序列
     * 第三击外一律放行。
     */
    fun onKeyDown(keyCode: Int): Boolean = when (state) {
        State.IDLE -> handleIdle(keyCode)
        State.ARMED -> {
            handlePasswordEntry(keyCode)
            isVolumeKey(keyCode)
        }
        State.RECORDING_NEW_PASSWORD -> {
            handleNewPasswordEntry(keyCode)
            isVolumeKey(keyCode)
        }
    }

    private fun isVolumeKey(keyCode: Int): Boolean =
        keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN

    // -----------------------------------------------------------------
    // 各状态处理
    // -----------------------------------------------------------------

    /**
     * 空闲态：检测"音量+ → 音量- → 音量+"交替序列（相邻间隔 ≤ [SEQUENCE_GAP_MS]）。
     * 非音量键忽略且不打断序列；普通连按同侧音量键（如连续调大/调小）不构成
     * 交替模式，不会误触发。
     */
    private fun handleIdle(keyCode: Int): Boolean {
        if (!isVolumeKey(keyCode)) return false
        val now = System.currentTimeMillis()
        val matched = prevKey == KeyEvent.KEYCODE_VOLUME_UP &&
            lastKey == KeyEvent.KEYCODE_VOLUME_DOWN &&
            keyCode == KeyEvent.KEYCODE_VOLUME_UP &&
            lastAt - prevAt <= SEQUENCE_GAP_MS &&
            now - lastAt <= SEQUENCE_GAP_MS
        if (matched) {
            prevKey = 0
            lastKey = 0
            armPasswordEntry()
            // 吞掉第三击：与第一击相抵，触发序列净音量变化为 0。
            return true
        }
        prevKey = lastKey
        prevAt = lastAt
        lastKey = keyCode
        lastAt = now
        return false
    }

    private fun handlePasswordEntry(keyCode: Int) {
        // 密码为 5 个音量键序列（默认全是音量"-"）；电源键等其它输入忽略，
        // 不重置倒计时，超时后静默失败。
        if (!isVolumeKey(keyCode)) return
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
        // 新密码由音量"+"/"-"任意序列组成（电源键不录入，避免触发系统手势）。
        if (!isVolumeKey(keyCode)) return
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
        toast("Emergency unlock: enter 5-key password")
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
        prevKey = 0
        lastKey = 0
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
