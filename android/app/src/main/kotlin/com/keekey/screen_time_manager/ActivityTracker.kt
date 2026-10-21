package com.keekey.screen_time_manager

import android.app.Activity
import java.lang.ref.WeakReference

/**
 * 跟踪当前处于前台的 Activity 弱引用。
 *
 * DevicePolicyManager.lockNow() 与 Activity.startLockTask() / stopLockTask()
 * 都需要 Activity 实例；而平台通道在 Application 预创建的 FlutterEngine 上注册，
 * 只有 Application context。通过在 MainActivity 的生命周期里回调本类，
 * 让通道方法能够取到当前 Activity。
 */
object ActivityTracker {

    @Volatile
    private var _current: WeakReference<Activity>? = null

    /** 当前前台 Activity；若无返回 null。 */
    val currentActivity: Activity?
        get() = _current?.get()?.takeIf { !it.isFinishing && !it.isDestroyed }

    /** 本应用 Activity 当前是否处于 resumed（真正可见可交互）状态。 */
    @Volatile
    var isResumed: Boolean = false
        private set

    fun onActivityResumed(activity: Activity) {
        _current = WeakReference(activity)
        isResumed = true
    }

    fun onActivityPaused(activity: Activity) {
        val cur = _current?.get()
        if (cur === activity) _current = null
        isResumed = false
    }

    fun onActivityDestroyed(activity: Activity) {
        val cur = _current?.get()
        if (cur === activity) _current = null
        isResumed = false
    }
}
