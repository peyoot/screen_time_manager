package com.keekey.screen_time_manager

import android.app.Activity
import android.app.ActivityManager
import android.app.Application
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.PowerManager

/**
 * 休息阶段的"不可退出"守卫。
 *
 * Android 上有两种 LockTask 状态：
 * - PINNED：普通应用 startLockTask() 进入的屏幕固定，系统**故意**保留
 *   长按"返回+最近任务"退出入口（防恶意软件锁死用户）；
 * - LOCKED：应用是 Device Owner 且经 setLockTaskPackages 白名单后进入的
 *   Kiosk 模式，无确认弹窗、无退出手势，真正不可退出。
 *
 * 本守卫在非 Device Owner 设备上提供两层兜底：
 * 1. 用户退出固定（[onLockTaskModeExiting] 回调）→ 立刻重新 startLockTask，
 *    Device Owner 下静默回到 LOCKED，普通模式下系统再次弹固定确认框；
 * 2. 用户强行切到其他任务（Activity 进入后台）→ 立即 lockNow() 熄屏，
 *    并尽力把 MainActivity 重新拉到前台（overlay 权限或系统宽限期内可成功），
 *    用户解锁后只能回到休息页。
 *
 * Device Owner 通过一次性 ADB 命令设置：
 *   adb shell dpm set-device-owner \
 *     com.keekey.screen_time_manager/.ScreenMonitorDeviceAdmin
 * 设置前设备上不能有任何账号；这是个人自管应用获得 Kiosk 能力的官方路径。
 */
object RestGuard {

    /** 休息期固定是否处于武装状态（仅 resting 阶段为 true）。 */
    @Volatile
    var armed: Boolean = false
        private set

    /** 武装休息守卫（进入 resting 时调用）。 */
    fun arm() {
        armed = true
    }

    /** 解除休息守卫（休息结束、应用主动 stopLockTask 之前调用）。 */
    fun disarm() {
        armed = false
    }

    /** 应用是否为 Device Owner（决定 startLockTask 是 Kiosk 还是普通固定）。 */
    fun isDeviceOwner(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(context.packageName)
    }

    /**
     * 应用是 Device Owner 时，把本应用加入 LockTask 白名单；
     * 之后 startLockTask() 直接进入不可退出的 LOCKED Kiosk 模式。
     */
    fun enableLockTaskForDeviceOwner(app: Application) {
        val dpm = app.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(app, ScreenMonitorDeviceAdmin::class.java)
        if (!dpm.isDeviceOwnerApp(app.packageName)) return
        try {
            dpm.setLockTaskPackages(admin, arrayOf(app.packageName))
        } catch (_: SecurityException) {
            // 极端情况下策略不可用，忽略：退化为普通固定模式。
        }
    }

    /** 注册 Activity 生命周期回调：检测用户强行切走时拉回 + 熄屏。 */
    fun register(app: Application) {
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}

            override fun onActivityResumed(activity: Activity) {}

            override fun onActivityPaused(activity: Activity) {}

            override fun onActivityStopped(activity: Activity) {
                if (activity !is MainActivity || !armed) return
                // 仅当固定模式已退出且屏幕仍亮着时判定为"用户强行切走"：
                // 正常熄屏（电源键 / 10 秒自动锁屏）期间固定模式仍为 PINNED/LOCKED。
                val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                if (am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) return
                val powerManager =
                    activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isInteractive) return

                bringBackAndLock(activity.applicationContext)
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    private fun bringBackAndLock(appContext: Context) {
        // 先尝试把休息页拉回前台（持有 SYSTEM_ALERT_WINDOW 权限的应用
        // 允许从后台启动 Activity；第 4 步权限引导会引导授予）。
        val relaunch = Intent(appContext, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
        runCatching { appContext.startActivity(relaunch) }
        // 无论拉回是否成功都熄屏：解锁后要么直接看到休息页，
        // 要么用户必须重新进入应用，使"切出去玩手机"无收益。
        lockNowIfAdmin(appContext)
    }

    private fun lockNowIfAdmin(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(context, ScreenMonitorDeviceAdmin::class.java)
        if (!dpm.isAdminActive(admin)) return
        runCatching { dpm.lockNow() }
    }
}
