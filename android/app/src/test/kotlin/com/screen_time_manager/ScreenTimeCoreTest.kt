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
}
