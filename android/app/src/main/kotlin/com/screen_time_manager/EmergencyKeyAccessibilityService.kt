package com.screen_time_manager

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * 紧急退出按键监听的无障碍服务。
 *
 * 普通应用在 Activity 中只能收到音量键，**电源键会被系统提前拦截**；
 * 带 `FLAG_REQUEST_FILTER_KEY_EVENTS` 的无障碍服务是普通应用观测电源键
 * （含屏幕固定 / Kiosk 期间）的唯一可靠途径。
 *
 * 本服务只做按键转发（→ [EmergencyKeyController]），不读取任何界面内容，
 * 也不消费事件（[onKeyEvent] 恒返回 false，音量键原有行为保持不变）。
 * 用户需在 系统设置 → 无障碍 中手动开启一次。
 */
class EmergencyKeyAccessibilityService : AccessibilityService() {

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event != null &&
            event.action == KeyEvent.ACTION_DOWN &&
            event.repeatCount == 0
        ) {
            EmergencyKeyController.onKeyDown(event.keyCode)
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
