package com.keekey.screen_time_manager

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 到点干预的悬浮层兜底（第 3 步）。
 *
 * 场景：到点干预请求发出后，若因权限或 ROM 限制未能把 [MainActivity] 拉到
 * 前台（Android 10+ 后台启动限制未豁免、部分国产 ROM 加固拦截），用户仍停留
 * 在其他应用上，休息/答题提醒会被淹没。此时用全屏遮罩盖在当前应用之上，
 * 阻挡其交互，并给出"打开应用"入口。
 *
 * 设计要点：
 * - 前提：SYSTEM_ALERT_WINDOW 已授权（Settings.canDrawOverlays）；
 * - 视图用代码构建（纯 android.widget），不依赖 Activity/主题，可直接用
 *   Application context + WindowManager 添加；
 * - 窗口参数：TYPE_APPLICATION_OVERLAY（API 26+，之下用已废弃的 TYPE_PHONE）、
 *   MATCH_PARENT、FLAG_NOT_FOCUSABLE（不抢按键，返回键留给底层应用）、
 *   不加 FLAG_NOT_TOUCH_MODAL——全屏窗口内触摸全部被本层消费，底层应用收不到；
 * - 显示时机：requestShow 延迟 [SHOW_DELAY_MS] 后检查 [ActivityTracker.isResumed]，
 *   Activity 已到前台则放弃，避免遮罩盖住自己的休息页；
 * - 隐藏时机：Activity 恢复前台（MainActivity.onResume）、干预撤销
 *   （dismissInterventionNotification）与紧急退出共用 hide()。
 */
object InterventionOverlay {

    /** 请求展示后的观察延迟：给 startActivity 这么长时间到前台。 */
    private const val SHOW_DELAY_MS = 2500L

    private const val PHASE_RESTING = "resting"

    private val mainHandler = Handler(Looper.getMainLooper())

    /** 已挂到 WindowManager 上的遮罩视图；null 表示当前无遮罩。 */
    private var attachedView: View? = null

    /** 最近一次请求的阶段，延迟检查触发时读取。 */
    private var pendingPhase: String? = null

    /** 请求代数：hide 后使尚未触发的延迟检查失效。 */
    private var generation = 0

    /**
     * 请求展示兜底遮罩：延迟 [SHOW_DELAY_MS] 后若 Activity 仍未到前台则显示。
     * 幂等：重复调用只更新阶段；已显示或已到前台时不重复添加。
     */
    fun requestShow(context: Context, phase: String?) {
        pendingPhase = phase
        val gen = ++generation
        mainHandler.postDelayed({
            if (gen == generation && attachedView == null && !ActivityTracker.isResumed) {
                show(context.applicationContext, pendingPhase)
            }
        }, SHOW_DELAY_MS)
    }

    /** 立即隐藏遮罩；未显示时为空操作。线程安全（内部切主线程）。 */
    fun hide() {
        generation++
        pendingPhase = null
        mainHandler.post {
            val view = attachedView ?: return@post
            attachedView = null
            val wm = view.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            runCatching { wm.removeView(view) }
        }
    }

    /** 实际添加遮罩（必须在主线程调用）。 */
    private fun show(context: Context, phase: String?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) {
            return
        }
        if (attachedView != null || ActivityTracker.isResumed) return
        try {
            val view = buildOverlayView(context, phase)
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.addView(view, buildLayoutParams())
            attachedView = view
        } catch (_: Exception) {
            // 添加失败（权限被运行时吊销等）：静默放弃，通知仍是兜底。
        }
    }

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            // NOT_FOCUSABLE：不抢物理按键；全屏窗口默认消费区域内触摸，
            // 不加 NOT_TOUCH_MODAL，确保底层应用收不到点击。
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
    }

    /** 代码构建遮罩内容：深色背景 + 阶段文案 + "打开应用"入口。 */
    private fun buildOverlayView(context: Context, phase: String?): View {
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val isRest = phase == PHASE_RESTING
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xF2000000.toInt())
            setPadding(dp(32), dp(32), dp(32), dp(32))
            // 标记可点击：吞掉整层触摸，防止穿透到底层应用。
            isClickable = true
            isFocusable = false
        }

        val title = TextView(context).apply {
            text = if (isRest) "Time to rest" else "Quick check-in"
            setTextColor(Color.WHITE)
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(context).apply {
            text = if (isRest) {
                "Screen time is up. Open the app to start your break."
            } else {
                "Screen time is up. Open the app to answer and continue."
            }
            setTextColor(0xB3FFFFFF.toInt())
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(28))
        }

        val button = TextView(context).apply {
            text = "Open app"
            setTextColor(Color.WHITE)
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            // 药丸形按钮背景（渐变圆角矩形），避免依赖主题属性。
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(0xFF00897B.toInt())
            }
            setPadding(dp(40), dp(14), dp(40), dp(14))
            // 用应用 context 启动需要 NEW_TASK；SINGLE_TOP 复用现有实例。
            setOnClickListener {
                val intent = Intent(context, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                }
                runCatching { context.startActivity(intent) }
            }
        }

        root.addView(title)
        root.addView(subtitle, dpWrap())
        root.addView(button)
        return root
    }

    /** 副标题布局参数（水平居中、宽度包裹内容）。 */
    private fun dpWrap(): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { gravity = Gravity.CENTER_HORIZONTAL }
}
