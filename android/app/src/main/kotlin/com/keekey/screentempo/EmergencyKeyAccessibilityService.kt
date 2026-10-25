package com.keekey.screen_time_manager

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * 紧急退出按键监听的无障碍服务。
 *
 * 为什么不用 Activity 的 dispatchKeyEvent：
 * 1. 屏幕固定 / Kiosk 期间需要保证事件可达，无障碍按键过滤在事件分发给
 *    窗口之前生效，不受焦点变化影响；
 * 2. 密码录入窗口内需要"吞掉"音量键（音量不变、面板不弹），只有无障碍
 *    服务能在系统调音量之前拦截（Activity 层只能阻止默认处理的很少一部分）。
 *
 * 本服务只做按键转发（→ [EmergencyKeyController]），不读取任何界面内容。
 * 除密码录入窗口内的音量键外不消费任何事件（音量键原有行为保持不变）。
 * 用户需在 系统设置 → 无障碍 中手动开启一次。
 */
class EmergencyKeyAccessibilityService : AccessibilityService() {

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false
        val isVolume = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        // 密码录入窗口：吞掉音量键的全部事件（按下/长按重复/抬起）。
        if (isVolume && EmergencyKeyController.capturingVolumeKeys) return true
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            // 空闲态仅用于检测触发序列；返回 true 表示吞掉（仅序列第三击）。
            return EmergencyKeyController.onKeyDown(event.keyCode)
        }
        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 本服务只关心物理按键，不处理界面事件。
    }

    override fun onInterrupt() {
        // 无需处理。
    }
}
