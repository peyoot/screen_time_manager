/**
 * HarmonyOS 平台通道注册器 + 原生权威计时核心宿主。
 *
 * 与 Android `ScreenMonitorChannels` / `TimeCoreHost` 对齐：
 * - MethodChannel `monitor`：启停监控（长时任务 + 屏幕轮询）、权限查询、
 *   计时配置下发、构建信息；`moveToBack` 恒 false。
 * - MethodChannel `intervention`：`request(resting)` → 发高优通知
 *   （wantAgent 点击拉起 EntryAbility）；`dismiss` → 撤销通知；
 *   熄屏 / 屏幕固定 HarmonyOS 无对应能力，恒 false / no-op。
 * - MethodChannel `core`：原生权威计时核心（ScreenTimeCore.ets）读写口，
 *   快照 Map 键与 Android CoreSnapshot.toMap 一致。
 * - EventChannel `screen_events`：轮询发现屏幕状态变化时推送（Dart 侧
 *   原生权威模式下仅作会话记录边界参考）。
 *
 * HarmonyOS 平台约束（⚠️ 需在 DevEco Studio 中验证标注的 API 行为）：
 * - 无系统悬浮窗权限、无法强制拉前台 / 锁屏：到点干预只能靠通知 + wantAgent。
 * - COMMON_EVENT_SCREEN_ON/OFF 为系统应用专属：只能轮询 display.isScreenOn()。
 * - 应用退后台即冻结：保活依赖长时任务（backgroundTaskManager，
 *   backgroundModes=dataTransfer + KEEP_BACKGROUND_RUNNING 权限）。
 */
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import display from '@ohos.display';
import notificationManager from '@ohos.notificationManager';
import preferences from '@ohos.data.preferences';
import wantAgent from '@ohos.app.ability.wantAgent';
import { BusinessError } from '@ohos.base';
import { common } from '@kit.AbilityKit';
import { FlutterEngine, MethodCall, MethodChannel, MethodResult, EventChannel } from '@ohos/flutter_ohos';

import {
  CoreClock,
  CoreEffect,
  CoreSnapshot,
  CoreStore,
  DEFAULT_DAILY_LIMIT,
  DEFAULT_QUIZ_SEC,
  DEFAULT_REST_SEC,
  ExemptionWindow,
  ScreenTimeCore,
} from './ScreenTimeCore';

const NAMESPACE: string = 'com.keekey.screentempo/platform';

/** 到点休息通知 ID（撤销时复用）。 */
const REST_NOTIFICATION_ID: number = 1003;

const PREFS_NAME: string = 'screen_tempo_core';

// ---------------------------------------------------------------------
// 时钟 / 持久化实现
// ---------------------------------------------------------------------

/** 系统时钟：HarmonyOS 无 elapsedRealtime 等价物，两时钟同取 Date.now()，
 *  时钟拨动由 ScreenTimeCore 的 MAX_DELTA_MS 钳制。 */
class SystemCoreClock implements CoreClock {
  wallMs(): number {
    return Date.now();
  }

  realtimeMs(): number {
    return Date.now();
  }

  dayKey(): string {
    const d = new Date();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }

  /** getDay() 为 0=周日 … 6=周六，转换为 1=周一 … 7=周日。 */
  localWeekday(): number {
    const d: number = new Date().getDay();
    return d === 0 ? 7 : d;
  }

  localMinuteOfDay(): number {
    const d = new Date();
    return d.getHours() * 60 + d.getMinutes();
  }
}

/** preferences 持久化（文件名与 Android SharedPreferences 保持一致）。 */
class PrefsCoreStore implements CoreStore {
  private prefs: preferences.Preferences;

  constructor(context: common.Context) {
    this.prefs = preferences.getPreferencesSync(context, { name: PREFS_NAME });
  }

  getLong(key: string, def: number): number {
    return this.prefs.getSync(key, def) as number;
  }

  getInt(key: string, def: number): number {
    return this.prefs.getSync(key, def) as number;
  }

  getString(key: string, def: string | null): string | null {
    return this.prefs.getSync(key, def ?? '') as string | null;
  }

  getBoolean(key: string, def: boolean): boolean {
    return this.prefs.getSync(key, def) as boolean;
  }

  put(values: Map<string, number | string | boolean>): void {
    values.forEach((value: number | string | boolean, key: string) => {
      this.prefs.putSync(key, value as preferences.ValueType);
    });
    this.prefs.flush();
  }
}

// ---------------------------------------------------------------------
// 计时核心宿主（进程内单例 + 屏幕轮询 + 长时任务）
// ---------------------------------------------------------------------

class TimeCoreHost {
  private static instance: TimeCoreHost | null = null;

  readonly core: ScreenTimeCore;
  private context: common.Context;
  private pollTimer: number = -1;
  private lastScreenOn: boolean = false;

  private constructor(context: common.Context) {
    this.context = context;
    this.core = new ScreenTimeCore(new SystemCoreClock(), new PrefsCoreStore(context));
  }

  static get(context: common.Context): TimeCoreHost {
    if (TimeCoreHost.instance === null) {
      TimeCoreHost.instance = new TimeCoreHost(context.getApplicationContext());
    }
    return TimeCoreHost.instance;
  }

  /** 启动监控：长时任务保活 + 每秒轮询屏幕状态驱动计时核心。 */
  start(): void {
    // 跨天重置 + 计时起点复位（不累计进程死亡区间）。
    this.core.prepareForTakeover();
    // 进程被杀重启后仍在休息 → 补发干预通知。
    if (this.core.restingNow) {
      this.applyEffect(CoreEffect.ENTER_REST);
    }
    this.startContinuousTask();
    if (this.pollTimer >= 0) return;
    this.pollTimer = setInterval(() => {
      this.pollOnce();
    }, 1000);
  }

  /** 停止监控：结束长时任务与轮询。 */
  stop(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    this.stopContinuousTask();
    this.dismissRestNotification();
  }

  get running(): boolean {
    return this.pollTimer >= 0;
  }

  /** 单次轮询：屏幕状态变化喂入核心 + 每秒 tick + 执行副作用。 */
  private pollOnce(): void {
    // ⚠️ DevEco 验证：display.isScreenOn() 在 API 12 的同步行为；
    // 若被废弃需换 display.isFoldable() 无关接口或移入 async。
    let isOn: boolean;
    try {
      isOn = display.isScreenOn();
    } catch (e) {
      isOn = this.lastScreenOn;
    }
    if (isOn !== this.lastScreenOn) {
      this.lastScreenOn = isOn;
      const effect: CoreEffect = this.core.setScreenState(isOn);
      this.applyEffect(effect);
      ScreenEventBus.emit(isOn);
    }
    this.applyEffect(this.core.tick());
  }

  /** 执行计时核心的状态转移副作用。 */
  applyEffect(effect: CoreEffect): void {
    if (effect === CoreEffect.ENTER_REST) {
      // HarmonyOS 无法强制拉前台：发高优通知，点击经 wantAgent 拉起。
      this.publishRestNotification();
    } else if (effect === CoreEffect.EXIT_REST) {
      this.dismissRestNotification();
    }
  }

  // -----------------------------------------------------------------
  // 长时任务（后台保活）
  // -----------------------------------------------------------------

  private startContinuousTask(): void {
    // ⚠️ DevEco 验证：API 12+ 推荐 ContinuousTaskRequest 重载；
    // 旧签名 startBackgroundRunning(context, mode, wantAgent) 在新 SDK
    // 可能标记废弃，需按当前 SDK 文档调整。
    try {
      const agentInfo: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: 'com.keekey.screentempo', abilityName: 'EntryAbility' }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      };
      wantAgent.getWantAgent(agentInfo).then((agent: object) => {
        backgroundTaskManager.startBackgroundRunning(
          this.context,
          backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
          agent,
        ).catch((err: BusinessError) => {
          console.error(`startBackgroundRunning failed: ${err.code} ${err.message}`);
        });
      });
    } catch (e) {
      console.error('startContinuousTask failed');
    }
  }

  private stopContinuousTask(): void {
    try {
      backgroundTaskManager.stopBackgroundRunning(this.context)
        .catch((err: BusinessError) => {
          console.error(`stopBackgroundRunning failed: ${err.code}`);
        });
    } catch (e) {
      console.error('stopContinuousTask failed');
    }
  }

  // -----------------------------------------------------------------
  // 到点干预通知（通知 + wantAgent 拉前台，唯一可用路径）
  // -----------------------------------------------------------------

  private publishRestNotification(): void {
    const agentInfo: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: 'com.keekey.screentempo', abilityName: 'EntryAbility' }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 1,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };
    wantAgent.getWantAgent(agentInfo).then((agent: object) => {
      const request: notificationManager.NotificationRequest = {
        id: REST_NOTIFICATION_ID,
        // 休息页全屏常驻，通知仅作"从其他应用回到休息页"的入口。
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '该休息了',
            text: '使用时间已达上限，点击回到休息页',
          },
        },
        wantAgent: agent,
      };
      notificationManager.publish(request).catch((err: BusinessError) => {
        console.error(`publish rest notification failed: ${err.code}`);
      });
    });
  }

  private dismissRestNotification(): void {
    try {
      notificationManager.cancel(REST_NOTIFICATION_ID);
    } catch (e) {
      // 无残留通知时静默
    }
  }
}

// ---------------------------------------------------------------------
// 亮灭屏事件总线（EventChannel 订阅桥）
// ---------------------------------------------------------------------

class ScreenEventBus {
  private static sink: EventSinkLike | null = null;

  static attach(sink: EventSinkLike): void {
    ScreenEventBus.sink = sink;
  }

  static detach(): void {
    ScreenEventBus.sink = null;
  }

  static emit(isScreenOn: boolean): void {
    ScreenEventBus.sink?.success(isScreenOn);
  }
}

/** flutter_ohos EventSink 的最小结构（避免依赖未确认的具体类型名）。 */
interface EventSinkLike {
  success(event: boolean): void;
}

// ---------------------------------------------------------------------
// 通道注册
// ---------------------------------------------------------------------

export class ScreenMonitorChannels {
  /** 在给定引擎上注册全部平台通道。 */
  static register(engine: FlutterEngine, context: common.Context): void {
    ScreenMonitorChannels.registerCore(engine, context);
    ScreenMonitorChannels.registerMonitor(engine, context);
    ScreenMonitorChannels.registerIntervention(engine, context);
    ScreenMonitorChannels.registerScreenEvents(engine, context);
  }

  private static registerCore(engine: FlutterEngine, context: common.Context): void {
    const channel = new MethodChannel(engine.dartExecutor, `${NAMESPACE}/core`);
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        const host = TimeCoreHost.get(context);
        const args = call.arguments as Record<string, Object> | null;
        switch (call.method) {
          case 'snapshot': {
            const snap: CoreSnapshot = host.core.snapshot();
            result.success(snap.toMap());
            break;
          }
          case 'configure':
            host.core.configure(
              ScreenMonitorChannels.numArg(args, 'quizSeconds', DEFAULT_QUIZ_SEC),
              ScreenMonitorChannels.numArg(args, 'restSeconds', DEFAULT_REST_SEC),
              ScreenMonitorChannels.numArg(args, 'dailyLimit', DEFAULT_DAILY_LIMIT),
              ScreenMonitorChannels.boolArg(args, 'restEnabled', true),
              ScreenMonitorChannels.parseExemptWindows(
                args !== null ? args['exemptWindows'] : undefined,
              ),
            );
            result.success(null);
            break;
          case 'manualRest':
            host.applyEffect(host.core.manualRest());
            result.success(null);
            break;
          case 'consumeExemption':
            host.applyEffect(host.core.consumeExemption());
            result.success(null);
            break;
          case 'seedFromSnapshot': {
            const seeded = host.core.seedFromSnapshot(
              ScreenMonitorChannels.numArg(args, 'usedTodaySec', 0) * 1000,
              ScreenMonitorChannels.numArg(args, 'thresholdSec', 0) * 1000,
              ScreenMonitorChannels.numArg(args, 'exemptionsUsed', 0),
              ScreenMonitorChannels.boolArg(args, 'resting', false),
              ScreenMonitorChannels.numArg(args, 'restEndsAtMs', 0),
            );
            result.success(seeded);
            break;
          }
          default:
            result.notImplemented();
        }
      },
    });
  }

  private static registerMonitor(engine: FlutterEngine, context: common.Context): void {
    const channel = new MethodChannel(engine.dartExecutor, `${NAMESPACE}/monitor`);
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        const host = TimeCoreHost.get(context);
        switch (call.method) {
          case 'startMonitoring':
            host.start();
            result.success(true);
            break;
          case 'stopMonitoring':
            host.stop();
            result.success(null);
            break;
          case 'isMonitoring':
            result.success(host.running);
            break;
          case 'getPermissions':
            // HarmonyOS 无悬浮窗 / 设备管理等权限项；长时任务权限在
            // module.json5 声明即生效，通知权限由系统弹窗管理。
            result.success({});
            break;
          case 'openPermissionSettings':
            // 无独立设置页可跳；引导由权限页展示"不可用"。
            result.success(null);
            break;
          case 'getAppInfo':
            result.success({ 'version': '1.0.0', 'flavor': 'free' });
            break;
          case 'moveToBack':
            result.success(false);
            break;
          default:
            result.notImplemented();
        }
      },
    });
  }

  private static registerIntervention(engine: FlutterEngine, context: common.Context): void {
    const channel = new MethodChannel(engine.dartExecutor, `${NAMESPACE}/intervention`);
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        const host = TimeCoreHost.get(context);
        switch (call.method) {
          case 'request': {
            const args = call.arguments as Record<string, string> | null;
            if (args !== null && args['phase'] === 'resting') {
              host.applyEffect(CoreEffect.ENTER_REST);
            }
            result.success(null);
            break;
          }
          case 'dismiss':
            host.applyEffect(CoreEffect.EXIT_REST);
            result.success(null);
            break;
          case 'lockScreen':
          case 'isDeviceAdminEnabled':
          case 'startScreenPinning':
          case 'stopScreenPinning':
            // HarmonyOS 无熄屏 / 屏幕固定 / 悬浮窗能力。
            result.success(false);
            break;
          case 'openDeviceAdminSettings':
            result.success(null);
            break;
          default:
            result.notImplemented();
        }
      },
    });
  }

  private static registerScreenEvents(engine: FlutterEngine, context: common.Context): void {
    const channel = new EventChannel(engine.dartExecutor, `${NAMESPACE}/screen_events`);
    // ⚠️ DevEco 验证：flutter_ohos EventChannel 的 setStreamHandler 签名。
    channel.setStreamHandler({
      onListen(args: object, sink: EventSinkLike): void {
        ScreenEventBus.attach(sink);
        try {
          sink.success(display.isScreenOn());
        } catch (e) {
          sink.success(false);
        }
      },
      onCancel(args: object): void {
        ScreenEventBus.detach();
      },
    });
  }

  private static numArg(
    args: Record<string, Object> | null,
    key: string,
    def: number,
  ): number {
    const v = args !== null ? args[key] : undefined;
    return typeof v === 'number' ? v : def;
  }

  private static boolArg(
    args: Record<string, Object> | null,
    key: string,
    def: boolean,
  ): boolean {
    const v = args !== null ? args[key] : undefined;
    return typeof v === 'boolean' ? v : def;
  }

  /** 解析 Dart 下发的豁免时间段列表；非法条目跳过，整体非法退化为空。 */
  private static parseExemptWindows(raw: Object | undefined): ExemptionWindow[] {
    if (!Array.isArray(raw)) return [];
    const parsed: ExemptionWindow[] = [];
    for (const item of raw) {
      const arg = item as ExemptWindowArg;
      if (arg === null || arg === undefined) continue;
      const start = arg.startMinute;
      const end = arg.endMinute;
      const days = arg.weekdays;
      if (typeof start !== 'number' || typeof end !== 'number' || !Array.isArray(days)) {
        continue;
      }
      if (start < 0 || start > 1439 || end < 0 || end > 1440 || start === end) {
        continue;
      }
      const weekdays: number[] = [];
      let valid = true;
      for (const d of days) {
        if (typeof d !== 'number' || d < 1 || d > 7) {
          valid = false;
          break;
        }
        weekdays.push(d);
      }
      if (!valid || weekdays.length === 0) continue;
      parsed.push(new ExemptionWindow(start, end, weekdays));
    }
    return parsed;
  }
}

/** Dart `ExemptionWindow.toJson()` 的通道侧结构。 */
interface ExemptWindowArg {
  startMinute: number;
  endMinute: number;
  weekdays: number[];
}
