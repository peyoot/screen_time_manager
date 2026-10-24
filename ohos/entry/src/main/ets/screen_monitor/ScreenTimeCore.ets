/**
 * 原生权威计时核心（ArkTS 移植，语义与 Android ScreenTimeCore.kt 完全对齐）。
 *
 * 设计要点（沿用 Android 版）：
 * - **单一权威时钟**：本类始终是唯一计时源；Dart 每秒经 `core` 通道读
 *   [snapshot] 镜像显示，用户操作（手动休息 / 豁免）经通道回写。
 * - 时长以毫秒累积、按 [CoreClock.realtimeMs] 差值推进。
 * - 状态与配置全部持久化到 [CoreStore]（preferences），供进程被回收后
 *   由长时任务拉起时复用。
 *
 * HarmonyOS 差异（⚠️ 需 DevEco 真机验证）：
 * - 无 `elapsedRealtime` 等价物：realtimeMs 同样取 `Date.now()`，
 *   依赖 MAX_DELTA_MS 钳制抵御时钟拨动（进程死亡区间的丢失语义不变）。
 * - 无全局亮灭屏广播（COMMON_EVENT_SCREEN_ON/OFF 仅系统应用可订阅）：
 *   屏幕状态由宿主每秒轮询 `display.isScreenOn()` 后经 [setScreenState] 喂入。
 */

/** 持久化键（与 Android `screen_time_core` SharedPreferences 保持一致）。 */
const KEY_DAY: string = 'day';
const KEY_SCREEN_MS: string = 'screen_ms';
const KEY_THRESHOLD_MS: string = 'threshold_ms';
const KEY_EXEMPTIONS_USED: string = 'exemptions_used';
const KEY_PHASE: string = 'phase';
const KEY_REST_ENDS_MS: string = 'rest_ends_at_ms';
const KEY_REST_START_MS: string = 'rest_start_ms';
const KEY_REST_COUNT: string = 'rest_count';
const KEY_REST_ELAPSED_MS: string = 'rest_elapsed_ms';
const KEY_REST_EXEMPTIONS: string = 'rest_exemptions';
const KEY_AWAY_MS: string = 'away_ms';
const KEY_PENDING_AWAY_START_MS: string = 'pending_away_start_ms';
const KEY_CONFIG_QUIZ_SEC: string = 'config_quiz_sec';
const KEY_CONFIG_REST_SEC: string = 'config_rest_sec';
const KEY_CONFIG_DAILY_LIMIT: string = 'config_daily_limit';
const KEY_CONFIG_REST_ENABLED: string = 'config_rest_enabled';
const KEY_IS_SCREEN_ON: string = 'is_screen_on';
const KEY_LAST_UPDATE_RT: string = 'last_update_realtime_ms';

/** 持久化节流间隔（发生状态转移时立即持久化）。 */
const PERSIST_THROTTLE_MS: number = 5000;

/** 单次累计上限：防止时钟异常跳变导致误计（1 小时）。 */
const MAX_DELTA_MS: number = 3600000;

/** 单个"远离手机"片段上限（24 小时）。 */
const MAX_AWAY_MS: number = 86400000;

const PHASE_TRACKING: string = 'tracking';
const PHASE_RESTING: string = 'resting';

export const DEFAULT_QUIZ_SEC: number = 900;
export const DEFAULT_REST_SEC: number = 180;
export const DEFAULT_DAILY_LIMIT: number = 2;

/** 计时核心的外部依赖注入接口：时钟。 */
export interface CoreClock {
  /** 墙钟毫秒（Date.now()）。 */
  wallMs(): number;

  /** 单调毫秒；HarmonyOS 无 elapsedRealtime 等价物，实现同 wallMs。 */
  realtimeMs(): number;

  /** 当地时区自然日键 `yyyy-MM-dd`。 */
  dayKey(): string;
}

/** 计时核心的外部依赖注入接口：持久化。 */
export interface CoreStore {
  getLong(key: string, def: number): number;
  getInt(key: string, def: number): number;
  getString(key: string, def: string | null): string | null;
  getBoolean(key: string, def: boolean): boolean;

  /** 批量写入（宿主负责节流后 flush）。 */
  put(values: Map<string, number | string | boolean>): void;
}

/** 计时核心状态转移结果，供宿主执行副作用。 */
export enum CoreEffect {
  /** 无转移。 */
  NONE,
  /** 进入休息：需发起干预（通知 + wantAgent 拉前台）。 */
  ENTER_REST,
  /** 休息结束：需撤销干预。 */
  EXIT_REST,
}

/** 计时核心对外快照（`core` 通道序列化用，键与 Android 版一致）。 */
export class CoreSnapshot {
  dayKey: string = '';
  screenTimeSec: number = 0;
  thresholdSec: number = 0;
  exemptionsUsedToday: number = 0;
  resting: boolean = false;
  restEndsAtMs: number = 0;
  restStartMs: number = 0;
  restCount: number = 0;
  restElapsedSec: number = 0;
  restExemptions: number = 0;
  /** 今日"远离手机"已完结片段累计（秒）。 */
  awaySec: number = 0;
  /** 挂起的"远离手机"片段起点（wall ms，0 表示无）。 */
  pendingAwayStartMs: number = 0;
  isScreenOn: boolean = false;
  quizIntervalSec: number = DEFAULT_QUIZ_SEC;
  restDurationSec: number = DEFAULT_REST_SEC;
  dailyExemptionLimit: number = DEFAULT_DAILY_LIMIT;
  hasDayData: boolean = false;

  /** 转为通道可传输的 Map（Dart TimeCoreSnapshot.fromMap 解析）。 */
  toMap(): Record<string, number | string | boolean> {
    return {
      'dayKey': this.dayKey,
      'screenTimeSec': this.screenTimeSec,
      'thresholdSec': this.thresholdSec,
      'exemptionsUsedToday': this.exemptionsUsedToday,
      'resting': this.resting,
      'restEndsAtMs': this.restEndsAtMs,
      'restStartMs': this.restStartMs,
      'restCount': this.restCount,
      'restElapsedSec': this.restElapsedSec,
      'restExemptions': this.restExemptions,
      'awaySec': this.awaySec,
      'pendingAwayStartMs': this.pendingAwayStartMs,
      'isScreenOn': this.isScreenOn,
      'quizIntervalSec': this.quizIntervalSec,
      'restDurationSec': this.restDurationSec,
      'dailyExemptionLimit': this.dailyExemptionLimit,
      'hasDayData': this.hasDayData,
    } as Record<string, number | string | boolean>;
  }
}

export class ScreenTimeCore {
  private clock: CoreClock;
  private store: CoreStore;

  /** 当日累计亮屏（毫秒）。 */
  private screenMs: number;
  /** 自上次豁免通过 / 休息结束以来的阈值进度（毫秒）。 */
  private thresholdMs: number;
  /** 今日已用豁免次数（状态机口径）。 */
  private exemptionsUsed: number;
  /** 当前是否处于休息阶段。 */
  private resting: boolean;
  /** 当前休息截止（wall ms，0 表示无）。 */
  private restEndsAtMs: number;
  /** 当前休息起点（wall ms，0 表示无）。 */
  private restStartMs: number;
  /** 今日触发休息次数（含进行中）。 */
  private restCount: number;
  /** 今日已完成休息的实际毫秒数（不含进行中）。 */
  private restElapsedMs: number;
  /** 今日休息期豁免次数。 */
  private restExemptions: number;
  /** 今日"远离手机"已完结片段累计（毫秒，不含进行中片段）。 */
  private awayMs: number;
  /** 挂起的"远离手机"片段起点（wall ms，0 表示无）。 */
  private pendingAwayStartMs: number;

  private configQuizSec: number;
  private configRestSec: number;
  private configDailyLimit: number;
  /** 强制休息功能总开关：关闭时只累计亮屏时长，阈值进度冻结。 */
  private configRestEnabled: boolean;

  private isScreenOn: boolean;
  private lastUpdateRtMs: number;
  private day: string;
  /** 原生是否已有当日数据（升级迁移判定用）。 */
  private hasDayData: boolean;

  private lastPersistRtMs: number = 0;

  constructor(clock: CoreClock, store: CoreStore) {
    this.clock = clock;
    this.store = store;
    const persistedDay = store.getString(KEY_DAY, null);
    this.hasDayData = persistedDay !== null;
    this.day = persistedDay ?? clock.dayKey();
    this.screenMs = store.getLong(KEY_SCREEN_MS, 0);
    this.thresholdMs = store.getLong(KEY_THRESHOLD_MS, 0);
    this.exemptionsUsed = store.getInt(KEY_EXEMPTIONS_USED, 0);
    this.resting = store.getString(KEY_PHASE, PHASE_TRACKING) === PHASE_RESTING;
    this.restEndsAtMs = store.getLong(KEY_REST_ENDS_MS, 0);
    this.restStartMs = store.getLong(KEY_REST_START_MS, 0);
    this.restCount = store.getInt(KEY_REST_COUNT, 0);
    this.restElapsedMs = store.getLong(KEY_REST_ELAPSED_MS, 0);
    this.restExemptions = store.getInt(KEY_REST_EXEMPTIONS, 0);
    this.awayMs = store.getLong(KEY_AWAY_MS, 0);
    this.pendingAwayStartMs = store.getLong(KEY_PENDING_AWAY_START_MS, 0);
    this.configQuizSec = store.getLong(KEY_CONFIG_QUIZ_SEC, DEFAULT_QUIZ_SEC);
    this.configRestSec = store.getLong(KEY_CONFIG_REST_SEC, DEFAULT_REST_SEC);
    this.configDailyLimit = store.getInt(KEY_CONFIG_DAILY_LIMIT, DEFAULT_DAILY_LIMIT);
    this.configRestEnabled = store.getBoolean(KEY_CONFIG_REST_ENABLED, true);
    this.isScreenOn = store.getBoolean(KEY_IS_SCREEN_ON, false);
    this.lastUpdateRtMs = store.getLong(KEY_LAST_UPDATE_RT, 0);
  }

  /** 服务启动时调用：跨天重置后把计时起点重置到当前时刻。
   *  不累计进程死亡期间的间隔——宁少勿多。 */
  prepareForTakeover(): void {
    this.rolloverDayIfNeeded();
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(true);
  }

  /** 更新配置（由 Dart 推送 settings，原生持久化供后台重启复用）。 */
  configure(quizSec: number, restSec: number, dailyLimit: number, restEnabled: boolean = true): void {
    this.configQuizSec = quizSec > 0 ? quizSec : DEFAULT_QUIZ_SEC;
    this.configRestSec = restSec > 0 ? restSec : DEFAULT_REST_SEC;
    this.configDailyLimit = dailyLimit >= 0 ? dailyLimit : DEFAULT_DAILY_LIMIT;
    this.configRestEnabled = restEnabled;
    this.persist(true);
  }

  /** 亮灭屏事件：切换前先把当前 interval 收尾累计，再翻转屏幕状态。 */
  setScreenState(isOn: boolean): CoreEffect {
    // 先跨天重置：隔夜亮屏时昨日的挂起片段应随跨天丢弃。
    this.rolloverDayIfNeeded();
    if (this.isScreenOn === isOn) {
      this.lastUpdateRtMs = this.clock.realtimeMs();
      return CoreEffect.NONE;
    }
    const effect: CoreEffect = !isOn ? this.accumulate() : CoreEffect.NONE;
    this.isScreenOn = isOn;
    const closedAway: boolean = isOn ? this.closePendingAwayOnScreenOn() : false;
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(effect !== CoreEffect.NONE || closedAway);
    return effect;
  }

  /** 每秒推进一次：休息到期处理 + 亮屏累计 + 阈值判定。 */
  tick(): CoreEffect {
    const dayChanged: boolean = this.rolloverDayIfNeeded();

    if (this.resting && this.clock.wallMs() >= this.restEndsAtMs) {
      this.endRestNaturally();
      this.lastUpdateRtMs = this.clock.realtimeMs();
      this.persist(true);
      return CoreEffect.EXIT_REST;
    }

    const effect: CoreEffect = this.accumulate();
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(dayChanged || effect !== CoreEffect.NONE);
    return effect;
  }

  /** 手动触发休息（UI 计时页"立即休息"）；强制休息关闭时拒绝。 */
  manualRest(): CoreEffect {
    this.rolloverDayIfNeeded();
    if (this.resting || !this.configRestEnabled) return CoreEffect.NONE;
    this.enterRest(this.clock.wallMs());
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(true);
    return CoreEffect.ENTER_REST;
  }

  /** 休息期答题豁免通过：消耗一次额度并结束休息。 */
  consumeExemption(): CoreEffect {
    this.rolloverDayIfNeeded();
    if (!this.resting) return CoreEffect.NONE;
    if (this.exemptionsUsed >= this.configDailyLimit) return CoreEffect.NONE;
    const nowWall: number = this.clock.wallMs();
    if (this.restStartMs > 0) {
      this.restElapsedMs += Math.max(nowWall - this.restStartMs, 0);
    }
    this.closeAwayEpisodeOnRestEnd(nowWall);
    this.exemptionsUsed++;
    this.restExemptions++;
    this.resting = false;
    this.restEndsAtMs = 0;
    this.restStartMs = 0;
    this.thresholdMs = 0;
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(true);
    return CoreEffect.EXIT_REST;
  }

  /** 升级迁移：原生从未有当日数据时用 Dart 侧旧快照初始化。 */
  seedFromSnapshot(
    usedTodayMs: number,
    thresholdMs: number,
    exemptionsUsed: number,
    resting: boolean,
    restEndsAtMs: number,
  ): boolean {
    if (this.hasDayData) return false;
    this.screenMs = Math.max(usedTodayMs, 0);
    this.thresholdMs = Math.max(thresholdMs, 0);
    this.exemptionsUsed = Math.max(exemptionsUsed, 0);
    this.resting = resting;
    this.restEndsAtMs = resting ? restEndsAtMs : 0;
    this.restStartMs = 0;
    this.day = this.clock.dayKey();
    this.hasDayData = true;
    this.lastUpdateRtMs = this.clock.realtimeMs();
    this.persist(true);
    return true;
  }

  /** 当前权威快照。 */
  snapshot(): CoreSnapshot {
    const s = new CoreSnapshot();
    s.dayKey = this.day;
    s.screenTimeSec = Math.floor(this.screenMs / 1000);
    s.thresholdSec = Math.floor(this.thresholdMs / 1000);
    s.exemptionsUsedToday = this.exemptionsUsed;
    s.resting = this.resting;
    s.restEndsAtMs = this.restEndsAtMs;
    s.restStartMs = this.restStartMs;
    s.restCount = this.restCount;
    s.restElapsedSec = Math.floor(this.restElapsedMs / 1000);
    s.restExemptions = this.restExemptions;
    s.awaySec = Math.floor(this.awayMs / 1000);
    s.pendingAwayStartMs = this.pendingAwayStartMs;
    s.isScreenOn = this.isScreenOn;
    s.quizIntervalSec = this.configQuizSec;
    s.restDurationSec = this.configRestSec;
    s.dailyExemptionLimit = this.configDailyLimit;
    s.hasDayData = this.hasDayData;
    return s;
  }

  /** 原生是否处于休息阶段（宿主补发干预用）。 */
  get restingNow(): boolean {
    return this.resting;
  }

  /** 当前屏幕状态（宿主轮询去重用）。 */
  get screenOn(): boolean {
    return this.isScreenOn;
  }

  // -----------------------------------------------------------------
  // 内部实现
  // -----------------------------------------------------------------

  /** 亮屏累计 + 阈值判定。仅在计时阶段且屏幕点亮时生效。
   *  强制休息关闭时只累计当日亮屏时长，阈值进度冻结，永不进入休息。 */
  private accumulate(): CoreEffect {
    if (this.resting || !this.isScreenOn) return CoreEffect.NONE;
    let delta: number = this.clock.realtimeMs() - this.lastUpdateRtMs;
    if (delta < 0) delta = 0;
    if (delta > MAX_DELTA_MS) delta = MAX_DELTA_MS;
    if (delta <= 0) return CoreEffect.NONE;
    this.screenMs += delta;
    if (!this.configRestEnabled) return CoreEffect.NONE;
    this.thresholdMs += delta;
    if (this.thresholdMs >= this.configQuizSec * 1000) {
      this.enterRest(this.clock.wallMs());
      return CoreEffect.ENTER_REST;
    }
    return CoreEffect.NONE;
  }

  /** 进入休息：设置截止与起点、当日次数 +1。 */
  private enterRest(nowWall: number): void {
    this.resting = true;
    this.restEndsAtMs = nowWall + this.configRestSec * 1000;
    this.restStartMs = nowWall;
    this.restCount++;
  }

  /** 自然完成休息：回到计时阶段、重置阈值进度，额度用尽时豁免归零。 */
  private endRestNaturally(): void {
    if (this.restStartMs > 0 && this.restEndsAtMs > this.restStartMs) {
      this.restElapsedMs += this.restEndsAtMs - this.restStartMs;
    }
    this.closeAwayEpisodeOnRestEnd(this.clock.wallMs());
    const resetExemptions: boolean = this.exemptionsUsed >= this.configDailyLimit;
    this.resting = false;
    this.restEndsAtMs = 0;
    this.restStartMs = 0;
    this.thresholdMs = 0;
    if (resetExemptions) this.exemptionsUsed = 0;
  }

  /** 休息结束时收尾"远离手机"片段：屏幕亮 → 立即计入；屏幕灭 → 挂起。 */
  private closeAwayEpisodeOnRestEnd(nowWall: number): void {
    if (this.restStartMs <= 0) return;
    if (this.isScreenOn) {
      this.awayMs += Math.min(Math.max(nowWall - this.restStartMs, 0), MAX_AWAY_MS);
    } else {
      this.pendingAwayStartMs = this.restStartMs;
    }
  }

  /** 亮屏时关闭挂起的"远离手机"片段。返回是否有片段被计入。 */
  private closePendingAwayOnScreenOn(): boolean {
    if (this.pendingAwayStartMs <= 0) return false;
    this.awayMs += Math.min(Math.max(this.clock.wallMs() - this.pendingAwayStartMs, 0), MAX_AWAY_MS);
    this.pendingAwayStartMs = 0;
    return true;
  }

  /** 跨自然日重置当日状态；进行中的休息带入新一天。返回是否跨天。 */
  private rolloverDayIfNeeded(): boolean {
    const today: string = this.clock.dayKey();
    if (today === this.day) return false;
    this.day = today;
    this.screenMs = 0;
    this.thresholdMs = 0;
    this.exemptionsUsed = 0;
    this.restCount = 0;
    this.restElapsedMs = 0;
    this.restExemptions = 0;
    this.awayMs = 0;
    this.pendingAwayStartMs = 0;
    if (this.resting) {
      // 跨天仍在休息：次数记 1，起点保留（影响有限）。
      this.restCount = 1;
    } else {
      this.restEndsAtMs = 0;
      this.restStartMs = 0;
    }
    return true;
  }

  private persist(force: boolean): void {
    const nowRt: number = this.clock.realtimeMs();
    if (!force && nowRt - this.lastPersistRtMs < PERSIST_THROTTLE_MS) return;
    this.lastPersistRtMs = nowRt;
    this.hasDayData = true;
    const values = new Map<string, number | string | boolean>();
    values.set(KEY_DAY, this.day);
    values.set(KEY_SCREEN_MS, this.screenMs);
    values.set(KEY_THRESHOLD_MS, this.thresholdMs);
    values.set(KEY_EXEMPTIONS_USED, this.exemptionsUsed);
    values.set(KEY_PHASE, this.resting ? PHASE_RESTING : PHASE_TRACKING);
    values.set(KEY_REST_ENDS_MS, this.restEndsAtMs);
    values.set(KEY_REST_START_MS, this.restStartMs);
    values.set(KEY_REST_COUNT, this.restCount);
    values.set(KEY_REST_ELAPSED_MS, this.restElapsedMs);
    values.set(KEY_REST_EXEMPTIONS, this.restExemptions);
    values.set(KEY_AWAY_MS, this.awayMs);
    values.set(KEY_PENDING_AWAY_START_MS, this.pendingAwayStartMs);
    values.set(KEY_CONFIG_QUIZ_SEC, this.configQuizSec);
    values.set(KEY_CONFIG_REST_SEC, this.configRestSec);
    values.set(KEY_CONFIG_DAILY_LIMIT, this.configDailyLimit);
    values.set(KEY_CONFIG_REST_ENABLED, this.configRestEnabled);
    values.set(KEY_IS_SCREEN_ON, this.isScreenOn);
    values.set(KEY_LAST_UPDATE_RT, this.lastUpdateRtMs);
    this.store.put(values);
  }
}
