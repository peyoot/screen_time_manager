package com.screen_time_manager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [ScreenTimeCore] 纯逻辑单元测试（JVM，无需 Android 环境）。
 *
 * 用可注入的假时钟与内存存储，确定的验证亮屏累计、阈值判定、
 * 休息起止、豁免消耗/额度重置与跨天重置。
 */
class ScreenTimeCoreTest {

    private class FakeClock : CoreClock {
        var wall: Long = 1_000_000L
        var rt: Long = 0L
        var day: String = "2026-01-01"

        override fun wallMs(): Long = wall
        override fun realtimeMs(): Long = rt
        override fun dayKey(): String = day
    }

    private class MemoryStore : CoreStore {
        private val longs = mutableMapOf<String, Long>()
        private val ints = mutableMapOf<String, Int>()
        private val strings = mutableMapOf<String, String>()
        private val bools = mutableMapOf<String, Boolean>()

        override fun getLong(key: String, def: Long): Long = longs[key] ?: def
        override fun getInt(key: String, def: Int): Int = ints[key] ?: def
        override fun getString(key: String, def: String?): String? = strings[key] ?: def
        override fun getBoolean(key: String, def: Boolean): Boolean = bools[key] ?: def

        override fun put(values: Map<String, Any>) {
            values.forEach { (key, value) ->
                when (value) {
                    is Long -> longs[key] = value
                    is Int -> ints[key] = value
                    is Boolean -> bools[key] = value
                    is String -> strings[key] = value
                }
            }
        }
    }

    private fun newCore(clock: FakeClock, store: MemoryStore): ScreenTimeCore {
        val core = ScreenTimeCore(clock, store)
        core.configure(60, 30, 2) // 阈值 60s，休息 30s，每日豁免 2 次
        core.prepareForTakeover()
        return core
    }

    @Test
    fun screenOnAccumulatesAndEntersRestAtThreshold() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000

        assertEquals(CoreEffect.ENTER_REST, core.tick())
        val snap = core.snapshot()
        assertTrue(snap.resting)
        assertEquals(60L, snap.screenTimeSec)
        assertEquals(30_000L, snap.restEndsAtMs - snap.restStartMs)
        assertEquals(1, snap.restCount)
    }

    @Test
    fun restEndsNaturallyAfterDuration() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        core.tick()
        val endsAt = core.snapshot().restEndsAtMs

        clock.wall = endsAt
        clock.rt += 30_000

        assertEquals(CoreEffect.EXIT_REST, core.tick())
        val snap = core.snapshot()
        assertFalse(snap.resting)
        assertEquals(0L, snap.thresholdSec)
        assertEquals(30L, snap.restElapsedSec)
    }

    @Test
    fun consumeExemptionEndsRestAndUsesLimit() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())

        clock.wall += 5_000
        assertEquals(CoreEffect.EXIT_REST, core.consumeExemption())
        val snap = core.snapshot()
        assertFalse(snap.resting)
        assertEquals(1, snap.exemptionsUsedToday)
        assertEquals(1, snap.restExemptions)
        assertEquals(0L, snap.thresholdSec)
        assertEquals(5L, snap.restElapsedSec)
    }

    @Test
    fun consumeExemptionRejectedWhenLimitExhausted() {
        val clock = FakeClock()
        val store = MemoryStore()
        val core = ScreenTimeCore(clock, store)
        core.configure(60, 30, 0) // 每日豁免 0 次
        core.prepareForTakeover()

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        assertEquals(CoreEffect.NONE, core.consumeExemption())
    }

    @Test
    fun naturalRestResetsExemptionsWhenExhausted() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        // 用掉 2 次豁免额度
        repeat(2) {
            core.setScreenState(true)
            clock.rt += 60_000
            assertEquals(CoreEffect.ENTER_REST, core.tick())
            clock.wall += 5_000
            assertEquals(CoreEffect.EXIT_REST, core.consumeExemption())
        }
        assertEquals(2, core.snapshot().exemptionsUsedToday)

        // 第三次到点后自然完成完整休息 → 豁免额度重置
        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        clock.wall = core.snapshot().restEndsAtMs
        clock.rt += 30_000
        assertEquals(CoreEffect.EXIT_REST, core.tick())
        assertEquals(0, core.snapshot().exemptionsUsedToday)
    }

    @Test
    fun screenOffStopsAccumulation() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 10_000
        core.setScreenState(false)

        clock.rt += 600_000 // 灭屏期间很长
        core.tick()

        assertEquals(10L, core.snapshot().screenTimeSec)
    }

    @Test
    fun crossDayResetsDailyState() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        // 累计 30s（小于 60s 阈值，保持在计时阶段）。
        core.setScreenState(true)
        clock.rt += 30_000
        core.tick()
        assertEquals(30L, core.snapshot().screenTimeSec)

        clock.day = "2026-01-02"
        clock.rt += 1_000
        core.tick()

        val snap = core.snapshot()
        assertEquals(1L, snap.screenTimeSec)
        assertEquals(1L, snap.thresholdSec)
        assertEquals(0, snap.exemptionsUsedToday)
        assertEquals(0, snap.restCount)
    }

    @Test
    fun persistedStateSurvivesRecreation() {
        val clock = FakeClock()
        val store = MemoryStore()
        val core = newCore(clock, store)

        core.setScreenState(true)
        clock.rt += 20_000
        core.tick()

        // 模拟进程重启：用同一存储重新构造核心
        val revived = ScreenTimeCore(clock, store)
        assertEquals(20L, revived.snapshot().screenTimeSec)
        assertTrue(revived.snapshot().hasDayData)
    }

    @Test
    fun seedFromSnapshotOnlyWhenNoDayData() {
        val clock = FakeClock()
        val store = MemoryStore()
        val core = ScreenTimeCore(clock, store)

        assertTrue(
            core.seedFromSnapshot(120_000, 30_000, 1, false, 0),
        )
        assertEquals(120L, core.snapshot().screenTimeSec)

        // 已有当日数据时不再 seed
        assertFalse(core.seedFromSnapshot(999_000, 0, 0, false, 0))
        assertEquals(120L, core.snapshot().screenTimeSec)
    }

    @Test
    fun restEndWithScreenOnCountsAwayImmediately() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        // 屏幕保持点亮，休息自然结束 → [restStart, now] 立即计入。
        clock.wall = core.snapshot().restEndsAtMs
        clock.rt += 30_000
        assertEquals(CoreEffect.EXIT_REST, core.tick())
        val snap = core.snapshot()
        assertEquals(30L, snap.awaySec)
        assertEquals(0L, snap.pendingAwayStartMs)
    }

    @Test
    fun restEndWithScreenOffPendsAwayUntilNextScreenOn() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        // 灭屏后休息结束 → 挂起到下次亮屏。
        core.setScreenState(false)
        clock.wall = core.snapshot().restEndsAtMs
        clock.rt += 30_000
        assertEquals(CoreEffect.EXIT_REST, core.tick())
        var snap = core.snapshot()
        assertEquals(0L, snap.awaySec)
        assertTrue(snap.pendingAwayStartMs > 0)

        // 灭屏 10s 后重新亮屏：计入 [restStart, 亮屏] 全程（30+10s）。
        clock.wall += 10_000
        clock.rt += 10_000
        core.setScreenState(true)
        snap = core.snapshot()
        assertEquals(40L, snap.awaySec)
        assertEquals(0L, snap.pendingAwayStartMs)
    }

    @Test
    fun exemptionCountsActualRestDurationIntoAway() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())

        clock.wall += 5_000
        assertEquals(CoreEffect.EXIT_REST, core.consumeExemption())
        assertEquals(5L, core.snapshot().awaySec)
    }

    @Test
    fun crossDayResetsAwayAndDropsPending() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        core.setScreenState(false)
        clock.wall = core.snapshot().restEndsAtMs
        clock.rt += 30_000
        assertEquals(CoreEffect.EXIT_REST, core.tick())
        assertTrue(core.snapshot().pendingAwayStartMs > 0)

        // 跨天：away 归零、挂起片段丢弃；次日亮屏不补记。
        clock.day = "2026-01-02"
        clock.rt += 1_000
        core.tick()
        val snap = core.snapshot()
        assertEquals(0L, snap.awaySec)
        assertEquals(0L, snap.pendingAwayStartMs)
        core.setScreenState(true)
        assertEquals(0L, core.snapshot().awaySec)
    }

    @Test
    fun awayPersistsAcrossRecreation() {
        val clock = FakeClock()
        val store = MemoryStore()
        val core = newCore(clock, store)

        core.setScreenState(true)
        clock.rt += 60_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        clock.wall += 5_000
        assertEquals(CoreEffect.EXIT_REST, core.consumeExemption())

        // 模拟进程重启：用同一存储重新构造核心，away 累计保留。
        val revived = ScreenTimeCore(clock, store)
        assertEquals(5L, revived.snapshot().awaySec)
    }

    @Test
    fun restDisabledNeverEntersRestButStillAccumulatesScreenTime() {
        val clock = FakeClock()
        val core = ScreenTimeCore(clock, MemoryStore())
        core.configure(60, 30, 2, restEnabled = false)
        core.prepareForTakeover()

        core.setScreenState(true)
        clock.rt += 120_000 // 远超 60s 阈值

        // 多次 tick 均不触发休息；亮屏时长照常累计，阈值进度冻结为 0。
        assertEquals(CoreEffect.NONE, core.tick())
        assertEquals(CoreEffect.NONE, core.tick())
        val snap = core.snapshot()
        assertFalse(snap.resting)
        assertEquals(120L, snap.screenTimeSec)
        assertEquals(0L, snap.thresholdSec)
    }

    @Test
    fun manualRestRejectedWhenRestDisabled() {
        val clock = FakeClock()
        val core = ScreenTimeCore(clock, MemoryStore())
        core.configure(60, 30, 2, restEnabled = false)
        core.prepareForTakeover()

        assertEquals(CoreEffect.NONE, core.manualRest())
        assertFalse(core.snapshot().resting)

        // 重新启用后手动休息恢复可用。
        core.configure(60, 30, 2, restEnabled = true)
        assertEquals(CoreEffect.ENTER_REST, core.manualRest())
        assertTrue(core.snapshot().resting)
    }

    @Test
    fun restEnabledFlagPersistsAcrossRecreation() {
        val clock = FakeClock()
        val store = MemoryStore()
        val core = ScreenTimeCore(clock, store)
        core.configure(60, 30, 2, restEnabled = false)

        // 模拟进程重启：重新构造的核心仍为关闭状态，阈值不触发。
        val revived = ScreenTimeCore(clock, store)
        revived.prepareForTakeover()
        revived.setScreenState(true)
        clock.rt += 120_000
        assertEquals(CoreEffect.NONE, revived.tick())
        assertFalse(revived.snapshot().resting)
        assertEquals(120L, revived.snapshot().screenTimeSec)
    }

    @Test
    fun thresholdFrozenWhileDisabledResumesAfterReEnable() {
        val clock = FakeClock()
        val core = newCore(clock, MemoryStore())

        // 先累计 40s 阈值进度，然后关闭开关推进 120s（进度冻结）。
        core.setScreenState(true)
        clock.rt += 40_000
        assertEquals(CoreEffect.NONE, core.tick())
        core.configure(60, 30, 2, restEnabled = false)
        clock.rt += 120_000
        assertEquals(CoreEffect.NONE, core.tick())
        assertEquals(40L, core.snapshot().thresholdSec)
        assertEquals(160L, core.snapshot().screenTimeSec)

        // 重新启用：从 40s 继续，再累计 20s 达到阈值 → 进入休息。
        core.configure(60, 30, 2, restEnabled = true)
        clock.rt += 20_000
        assertEquals(CoreEffect.ENTER_REST, core.tick())
        assertTrue(core.snapshot().resting)
    }
}
