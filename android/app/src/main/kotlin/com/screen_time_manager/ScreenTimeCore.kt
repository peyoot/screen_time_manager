package com.screen_time_manager

/**
 * 原生权威计时核心（纯 Kotlin 逻辑，无 Android 依赖，可 JUnit 测试）。
 *
 * 背景：Dart 入口被推迟到 MainActivity 窗口就绪后才执行（避免后台拉起进程
 * 时缓存引擎无视图可附着导致黑屏）。因此开机广播 / 划卡闹钟在无 Activity 的
 * 后台拉起进程时 Dart 不运行，原状态机无法计时与干预。本类把"亮屏累计、阈值
 * 判定、到点干预时机"下沉到原生：只要进程被拉起（前台服务运行），原生即持续
 * 计时；Dart 仅作为 UI 层每秒读取 [snapshot] 镜像显示。
 *
 * 设计要点：
 * - **单一权威时钟**：本类始终是唯一计时源，不存在与 Dart 的时钟交接竞态。
 * - 时长以毫秒累积、以 [CoreClock.realtimeMs]（elapsedRealtime）差值推进，
 *   进程死亡后该时钟仍连续，1~5 秒的重启空窗影响可忽略。
 * - 状态与配置全部持久化到 [CoreStore]，供后台拉起（服务未与 Dart 通信）时复用。
 */
class ScreenTimeCore(
    private val clock: CoreClock,
    private val store: CoreStore,
) {

    companion object {
        const val DEFAULT_QUIZ_SEC = 900L
        const val DEFAULT_REST_SEC = 600L
        const val DEFAULT_DAILY_LIMIT = 2

        private const val KEY_DAY = "day"
        private const val KEY_SCREEN_MS = "screen_ms"
        private const val KEY_THRESHOLD_MS = "threshold_ms"
        private const val KEY_EXEMPTIONS_USED = "exemptions_used"
        private const val KEY_PHASE = "phase"
        private const val KEY_REST_ENDS_MS = "rest_ends_at_ms"
        private const val KEY_REST_START_MS = "rest_start_ms"
        private const val KEY_REST_COUNT = "rest_count"
        private const val KEY_REST_ELAPSED_MS = "rest_elapsed_ms"
        private const val KEY_REST_EXEMPTIONS = "rest_exemptions"
        private const val KEY_CONFIG_QUIZ_SEC = "config_quiz_sec"
        private const val KEY_CONFIG_REST_SEC = "config_rest_sec"
        private const val KEY_CONFIG_DAILY_LIMIT = "config_daily_limit"
        private const val KEY_IS_SCREEN_ON = "is_screen_on"
        private const val KEY_LAST_UPDATE_RT = "last_update_realtime_ms"
        private const val KEY_AWAY_MS = "away_ms"
        private const val KEY_PENDING_AWAY_START_MS = "pending_away_start_ms"

        /** 持久化节流间隔（发生状态转移时立即持久化）。 */
        private const val PERSIST_THROTTLE_MS = 5_000L

        /** 单次累计上限：防止时钟异常跳变导致误计（1 小时）。 */
        private const val MAX_DELTA_MS = 3_600_000L

        /** 单个"远离手机"片段上限（24 小时）：片段按 wall 时钟计算，
         * 仅用以防墙钟被用户/系统异常拨动产生离谱值；跨天重置会先行丢弃挂起片段。 */
        private const val MAX_AWAY_MS = 86_400_000L

        private const val PHASE_TRACKING = "tracking"
        private const val PHASE_RESTING = "resting"
    }

    /** 当日累计亮屏（毫秒）。 */
    private var screenMs: Long

    /** 自上次豁免通过 / 休息结束以来的阈值进度（毫秒）。 */
    private var thresholdMs: Long

    /** 今日已用豁免次数（状态机口径）。 */
    private var exemptionsUsed: Int

    /** 当前阶段。 */
    private var resting: Boolean

    /** 当前休息截止（wall ms，0 表示无）。 */
    private var restEndsAtMs: Long

    /** 当前休息起点（wall ms，0 表示无）。 */
    private var restStartMs: Long

    /** 今日触发休息次数（含进行中）。 */
    private var restCount: Int

    /** 今日已完成休息的实际毫秒数（不含进行中）。 */
    private var restElapsedMs: Long

    /** 今日休息期豁免次数。 */
    private var restExemptions: Int

    /** 今日"远离手机"已完结片段累计（毫秒，不含进行中片段）。 */
    private var awayMs: Long

    /** 挂起的"远离手机"片段起点（wall ms，0 表示无）：
     * 休息自然结束/豁免结束时屏幕是灭的，片段延续到下次亮屏才计入。 */
    private var pendingAwayStartMs: Long

    private var configQuizSec: Long
    private var configRestSec: Long
    private var configDailyLimit: Int

    private var isScreenOn: Boolean
    private var lastUpdateRtMs: Long
    private var day: String

    /** 原生是否已有当日数据（用于升级迁移判定，见 [seedFromSnapshot]）。 */
    private var hasDayData: Boolean

    private var lastPersistRtMs: Long = 0L

    init {
        val persistedDay = store.getString(KEY_DAY, null)
        hasDayData = persistedDay != null
        day = persistedDay ?: clock.dayKey()
        screenMs = store.getLong(KEY_SCREEN_MS, 0)
        thresholdMs = store.getLong(KEY_THRESHOLD_MS, 0)
        exemptionsUsed = store.getInt(KEY_EXEMPTIONS_USED, 0)
        resting = store.getString(KEY_PHASE, PHASE_TRACKING) == PHASE_RESTING
        restEndsAtMs = store.getLong(KEY_REST_ENDS_MS, 0)
        restStartMs = store.getLong(KEY_REST_START_MS, 0)
        restCount = store.getInt(KEY_REST_COUNT, 0)
        restElapsedMs = store.getLong(KEY_REST_ELAPSED_MS, 0)
        restExemptions = store.getInt(KEY_REST_EXEMPTIONS, 0)
        awayMs = store.getLong(KEY_AWAY_MS, 0)
        pendingAwayStartMs = store.getLong(KEY_PENDING_AWAY_START_MS, 0)
        configQuizSec = store.getLong(KEY_CONFIG_QUIZ_SEC, DEFAULT_QUIZ_SEC)
        configRestSec = store.getLong(KEY_CONFIG_REST_SEC, DEFAULT_REST_SEC)
        configDailyLimit = store.getInt(KEY_CONFIG_DAILY_LIMIT, DEFAULT_DAILY_LIMIT)
        isScreenOn = store.getBoolean(KEY_IS_SCREEN_ON, false)
        lastUpdateRtMs = store.getLong(KEY_LAST_UPDATE_RT, 0)
    }

    /** 服务启动时调用：跨天重置后把计时起点重置到当前时刻。
     *
     * 不累计进程死亡 / 深度睡眠期间的间隔——重启后无法得知该区间屏幕状态，
     * 宁少勿多；丢失窗口 ≤ 重启闹钟延迟（约 1~5 秒）。 */
    fun prepareForTakeover() {
        rolloverDayIfNeeded()
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = true)
    }

    /** 更新配置（由 Dart 推送 settings，原生持久化供后台重启复用）。 */
    fun configure(quizSec: Long, restSec: Long, dailyLimit: Int) {
        configQuizSec = if (quizSec > 0) quizSec else DEFAULT_QUIZ_SEC
        configRestSec = if (restSec > 0) restSec else DEFAULT_REST_SEC
        configDailyLimit = if (dailyLimit >= 0) dailyLimit else DEFAULT_DAILY_LIMIT
        persist(force = true)
    }

    /** 亮灭屏事件：切换前先把当前 interval 收尾累计，再翻转屏幕状态。 */
    fun setScreenState(isOn: Boolean): CoreEffect {
        // 先跨天重置：隔夜亮屏时昨日的挂起"远离手机"片段应随跨天丢弃，
        // 不能计入新的一天。
        rolloverDayIfNeeded()
        if (isScreenOn == isOn) {
            lastUpdateRtMs = clock.realtimeMs()
            return CoreEffect.NONE
        }
        val effect = if (!isOn) accumulate() else CoreEffect.NONE
        isScreenOn = isOn
        val closedAway = if (isOn) closePendingAwayOnScreenOn() else false
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = effect != CoreEffect.NONE || closedAway)
        return effect
    }

    /** 每秒推进一次：休息到期处理 + 亮屏累计 + 阈值判定。
     *
     * @return 进入休息（[CoreEffect.ENTER_REST]）/ 休息结束（[CoreEffect.EXIT_REST]），
     *         供原生宿主执行干预与屏幕固定等副作用。 */
    fun tick(): CoreEffect {
        val dayChanged = rolloverDayIfNeeded()

        if (resting && clock.wallMs() >= restEndsAtMs) {
            endRestNaturally()
            lastUpdateRtMs = clock.realtimeMs()
            persist(force = true)
            return CoreEffect.EXIT_REST
        }

        val effect = accumulate()
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = dayChanged || effect != CoreEffect.NONE)
        return effect
    }

    /** 手动触发休息（UI 计时页"立即休息"）。 */
    fun manualRest(): CoreEffect {
        rolloverDayIfNeeded()
        if (resting) return CoreEffect.NONE
        enterRest(clock.wallMs())
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = true)
        return CoreEffect.ENTER_REST
    }

    /** 休息期答题豁免通过：消耗一次额度并结束休息。 */
    fun consumeExemption(): CoreEffect {
        rolloverDayIfNeeded()
        if (!resting) return CoreEffect.NONE
        if (exemptionsUsed >= configDailyLimit) return CoreEffect.NONE
        val nowWall = clock.wallMs()
        if (restStartMs > 0) restElapsedMs += (nowWall - restStartMs).coerceAtLeast(0)
        closeAwayEpisodeOnRestEnd(nowWall)
        exemptionsUsed++
        restExemptions++
        resting = false
        restEndsAtMs = 0
        restStartMs = 0
        thresholdMs = 0
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = true)
        return CoreEffect.EXIT_REST
    }

    /** 升级迁移：原生从未有当日数据时，用 Dart 侧旧快照初始化，避免首次
     * 切到原生模式时当日数据归零。返回是否已写入。 */
    fun seedFromSnapshot(
        usedTodayMs: Long,
        thresholdMs: Long,
        exemptionsUsed: Int,
        resting: Boolean,
        restEndsAtMs: Long,
    ): Boolean {
        if (hasDayData) return false
        this.screenMs = usedTodayMs.coerceAtLeast(0)
        this.thresholdMs = thresholdMs.coerceAtLeast(0)
        this.exemptionsUsed = exemptionsUsed.coerceAtLeast(0)
        this.resting = resting
        this.restEndsAtMs = if (resting) restEndsAtMs else 0
        this.restStartMs = 0
        this.day = clock.dayKey()
        hasDayData = true
        lastUpdateRtMs = clock.realtimeMs()
        persist(force = true)
        return true
    }

    /** 当前权威快照。 */
    fun snapshot(): CoreSnapshot = CoreSnapshot(
        dayKey = day,
        screenTimeSec = screenMs / 1000,
        thresholdSec = thresholdMs / 1000,
        exemptionsUsedToday = exemptionsUsed,
        resting = resting,
        restEndsAtMs = restEndsAtMs,
        restStartMs = restStartMs,
        restCount = restCount,
        restElapsedSec = restElapsedMs / 1000,
        restExemptions = restExemptions,
        awaySec = awayMs / 1000,
        pendingAwayStartMs = pendingAwayStartMs,
        isScreenOn = isScreenOn,
        quizIntervalSec = configQuizSec,
        restDurationSec = configRestSec,
        dailyExemptionLimit = configDailyLimit,
        hasDayData = hasDayData,
    )

    // -----------------------------------------------------------------
    // 内部实现
    // -----------------------------------------------------------------

    /** 亮屏累计 + 阈值判定。仅在计时阶段且屏幕点亮时生效。 */
    private fun accumulate(): CoreEffect {
        if (resting || !isScreenOn) return CoreEffect.NONE
        var delta = clock.realtimeMs() - lastUpdateRtMs
        if (delta < 0) delta = 0            // 重启后 elapsedRealtime 归零 → 视为 0
        if (delta > MAX_DELTA_MS) delta = MAX_DELTA_MS
        if (delta <= 0) return CoreEffect.NONE
        screenMs += delta
        thresholdMs += delta
        if (thresholdMs >= configQuizSec * 1000) {
            enterRest(clock.wallMs())
            return CoreEffect.ENTER_REST
        }
        return CoreEffect.NONE
    }

    /** 进入休息：设置截止与起点、当日次数 +1。 */
    private fun enterRest(nowWall: Long) {
        resting = true
        restEndsAtMs = nowWall + configRestSec * 1000
        restStartMs = nowWall
        restCount++
    }

    /** 自然完成休息：回到计时阶段、重置阈值进度，额度用尽时豁免归零。 */
    private fun endRestNaturally() {
        if (restStartMs > 0 && restEndsAtMs > restStartMs) {
            restElapsedMs += restEndsAtMs - restStartMs
        }
        closeAwayEpisodeOnRestEnd(clock.wallMs())
        val resetExemptions = exemptionsUsed >= configDailyLimit
        resting = false
        restEndsAtMs = 0
        restStartMs = 0
        thresholdMs = 0
        if (resetExemptions) exemptionsUsed = 0
    }

    /** 休息结束（自然完成或豁免通过）时收尾"远离手机"片段：
     * 屏幕亮 → 立即计入 [restStartMs, nowWall]；屏幕灭 → 挂起到下次亮屏
     * （片段起点仍是 restStartMs，延续期间用户一直没碰手机）。 */
    private fun closeAwayEpisodeOnRestEnd(nowWall: Long) {
        if (restStartMs <= 0) return
        if (isScreenOn) {
            awayMs += (nowWall - restStartMs).coerceIn(0, MAX_AWAY_MS)
        } else {
            pendingAwayStartMs = restStartMs
        }
    }

    /** 亮屏时关闭挂起的"远离手机"片段。返回是否有片段被计入。 */
    private fun closePendingAwayOnScreenOn(): Boolean {
        if (pendingAwayStartMs <= 0) return false
        awayMs += (clock.wallMs() - pendingAwayStartMs).coerceIn(0, MAX_AWAY_MS)
        pendingAwayStartMs = 0
        return true
    }

    /** 跨自然日重置当日状态；进行中的休息带入新一天。返回是否跨天。 */
    private fun rolloverDayIfNeeded(): Boolean {
        val today = clock.dayKey()
        if (today == day) return false
        day = today
        screenMs = 0
        thresholdMs = 0
        exemptionsUsed = 0
        restCount = 0
        restElapsedMs = 0
        restExemptions = 0
        awayMs = 0
        pendingAwayStartMs = 0
        if (resting) {
            // 跨天仍在休息：次数记 1，起点保留（影响有限）。
            restCount = 1
        } else {
            restEndsAtMs = 0
            restStartMs = 0
        }
        return true
    }

    private fun persist(force: Boolean) {
        val nowRt = clock.realtimeMs()
        if (!force && nowRt - lastPersistRtMs < PERSIST_THROTTLE_MS) return
        lastPersistRtMs = nowRt
        hasDayData = true
        store.put(
            mapOf(
                KEY_DAY to day,
                KEY_SCREEN_MS to screenMs,
                KEY_THRESHOLD_MS to thresholdMs,
                KEY_EXEMPTIONS_USED to exemptionsUsed,
                KEY_PHASE to if (resting) PHASE_RESTING else PHASE_TRACKING,
                KEY_REST_ENDS_MS to restEndsAtMs,
                KEY_REST_START_MS to restStartMs,
                KEY_REST_COUNT to restCount,
                KEY_REST_ELAPSED_MS to restElapsedMs,
                KEY_REST_EXEMPTIONS to restExemptions,
                KEY_AWAY_MS to awayMs,
                KEY_PENDING_AWAY_START_MS to pendingAwayStartMs,
                KEY_CONFIG_QUIZ_SEC to configQuizSec,
                KEY_CONFIG_REST_SEC to configRestSec,
                KEY_CONFIG_DAILY_LIMIT to configDailyLimit,
                KEY_IS_SCREEN_ON to isScreenOn,
                KEY_LAST_UPDATE_RT to lastUpdateRtMs,
            ),
        )
    }
}

/** 原生计时核心的外部依赖注入接口：时钟。 */
interface CoreClock {
    /** 墙钟毫秒（System.currentTimeMillis）。 */
    fun wallMs(): Long

    /** 自开机起的单调毫秒（SystemClock.elapsedRealtime），跨进程死亡连续。 */
    fun realtimeMs(): Long

    /** 当地时区自然日键 `yyyy-MM-dd`。 */
    fun dayKey(): String
}

/** 原生计时核心的外部依赖注入接口：持久化。 */
interface CoreStore {
    fun getLong(key: String, def: Long): Long
    fun getInt(key: String, def: Int): Int
    fun getString(key: String, def: String?): String?
    fun getBoolean(key: String, def: Boolean): Boolean

    /** 批量写入。 */
    fun put(values: Map<String, Any>)
}

/** 计时核心状态转移结果，供原生宿主执行副作用。 */
enum class CoreEffect {
    /** 无转移。 */
    NONE,

    /** 进入休息：需发起全屏干预并武装屏幕固定。 */
    ENTER_REST,

    /** 休息结束：需撤销干预并解除屏幕固定。 */
    EXIT_REST,
}

/** 计时核心对外快照（通道序列化用）。 */
data class CoreSnapshot(
    val dayKey: String,
    val screenTimeSec: Long,
    val thresholdSec: Long,
    val exemptionsUsedToday: Int,
    val resting: Boolean,
    val restEndsAtMs: Long,
    val restStartMs: Long,
    val restCount: Int,
    val restElapsedSec: Long,
    val restExemptions: Int,
    /** 今日"远离手机"已完结片段累计（秒，不含进行中/挂起片段）。 */
    val awaySec: Long,
    /** 挂起的"远离手机"片段起点（wall ms，0 表示无）。 */
    val pendingAwayStartMs: Long,
    val isScreenOn: Boolean,
    val quizIntervalSec: Long,
    val restDurationSec: Long,
    val dailyExemptionLimit: Int,
    val hasDayData: Boolean,
) {
    /** 转为通道可传输的 Map。 */
    fun toMap(): Map<String, Any> = mapOf(
        "dayKey" to dayKey,
        "screenTimeSec" to screenTimeSec,
        "thresholdSec" to thresholdSec,
        "exemptionsUsedToday" to exemptionsUsedToday,
        "resting" to resting,
        "restEndsAtMs" to restEndsAtMs,
        "restStartMs" to restStartMs,
        "restCount" to restCount,
        "restElapsedSec" to restElapsedSec,
        "restExemptions" to restExemptions,
        "awaySec" to awaySec,
        "pendingAwayStartMs" to pendingAwayStartMs,
        "isScreenOn" to isScreenOn,
        "quizIntervalSec" to quizIntervalSec,
        "restDurationSec" to restDurationSec,
        "dailyExemptionLimit" to dailyExemptionLimit,
        "hasDayData" to hasDayData,
    )
}
