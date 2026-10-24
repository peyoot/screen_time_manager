/// Flutter ↔ Android 原生平台通道定义。
///
/// 所有通道共用命名空间 `com.keekey.screen_time_manager/platform`：
/// - EventChannel `screen_events`：原生 → Dart 的亮屏（true）/灭屏（false）事件；
/// - MethodChannel `monitor`：监控服务的启停控制与权限查询/跳转；
/// - MethodChannel `intervention`：Dart 进入答题/休息阶段时请求原生把界面拉到前台。
///
/// 本文件只依赖 `flutter/services`，不引入 `dart:io`，可在任意平台编译；
/// 是否真正接线由 [platform_monitoring] 的条件导入决定。
library;

import 'package:flutter/services.dart';

import '../models/app_settings.dart';

/// 通道统一命名空间。
const String kPlatformChannelNamespace = 'com.keekey.screen_time_manager/platform';

// ---------------------------------------------------------------------
// 亮灭屏事件
// ---------------------------------------------------------------------

/// 亮灭屏事件流：原生在屏幕点亮/熄灭时各推送一个布尔值。
///
/// 订阅建立时原生会先推送当前屏幕状态，避免冷启动阶段状态未知。
class ScreenEventStream {
  ScreenEventStream({EventChannel? channel})
      : _channel = channel ??
            const EventChannel('$kPlatformChannelNamespace/screen_events');

  final EventChannel _channel;

  /// 亮屏事件流；true 表示亮屏，false 表示灭屏。
  Stream<bool> events() =>
      _channel.receiveBroadcastStream().map((event) => event == true);
}

// ---------------------------------------------------------------------
// 监控服务 / 权限
// ---------------------------------------------------------------------

/// 监控运行所需的系统权限项（与原生 `getPermissions` 返回的 key 对应）。
enum MonitorPermission {
  /// `SYSTEM_ALERT_WINDOW` 悬浮窗权限。
  overlay,

  /// 电池优化白名单（不被 Doze 限制后台）。
  ignoreBatteryOptimizations,

  /// 通知权限（Android 13+ 运行时权限）。
  notifications,

  /// 全屏 intent 授权（Android 14+ 默认不授予普通应用）。
  fullScreenIntent,

  /// 无障碍服务授权（紧急退出按键监听依赖它来观测电源键）。
  accessibility,

  /// 精确闹钟授权（SCHEDULE_EXACT_ALARM，Android 12+；14+ 默认拒绝）。
  /// 划掉应用后自动重启监控依赖它；未授权时退化为非精确闹钟兜底。
  exactAlarm,

  /// 设备管理器授权（force-lock 策略）。
  /// 休息页展示后 10 秒内无答题豁免操作时自动熄屏（lockNow）依赖它；
  /// 未授权时休息页常亮当秒表。
  deviceAdmin,

  /// OEM 自启动管理（无公开 API，仅提供跳转，无状态查询）。
  autoStart,

  /// iOS Family Controls（屏幕使用时间）授权。
  ///
  /// 仅 iOS 使用：iOS 无法监听全局亮灭屏，只能经 Screen Time API
  /// 监控用户选定的应用；该授权是一切监控/屏蔽能力的前提。
  /// Android 的 `getPermissions` 不会返回此键。
  screenTime,
}

/// `monitor` 通道的 Dart 侧封装。
class MonitorChannel {
  MonitorChannel({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('$kPlatformChannelNamespace/monitor');

  final MethodChannel _channel;

  /// 请求原生开始监控（启动前台服务/注册亮灭屏广播）。
  /// 返回原生侧监控是否处于运行状态。
  Future<bool> startMonitoring() async {
    return await _channel.invokeMethod<bool>('startMonitoring') ?? false;
  }

  /// 请求原生停止监控。
  Future<void> stopMonitoring() {
    return _channel.invokeMethod<void>('stopMonitoring');
  }

  /// 查询原生侧监控是否正在运行。
  Future<bool> isMonitoring() async {
    return await _channel.invokeMethod<bool>('isMonitoring') ?? false;
  }

  /// 查询各项权限是否已授予；未实现的平台返回空表。
  Future<Map<MonitorPermission, bool>> getPermissions() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('getPermissions');
    if (raw == null) return const {};
    return <MonitorPermission, bool>{
      for (final permission in MonitorPermission.values)
        if (raw[permission.name] is bool)
          permission: raw[permission.name] as bool,
    };
  }

  /// 跳转到指定权限的系统设置页。
  Future<void> openPermissionSettings(MonitorPermission permission) {
    return _channel.invokeMethod<void>(
      'openPermissionSettings',
      <String, String>{'kind': permission.name},
    );
  }

  /// 把应用切到后台继续运行（不销毁进程，等价于按 Home）。
  /// Android 走 Activity.moveTaskToBack(true)；返回是否成功。
  Future<bool> moveToBack() async {
    return await _channel.invokeMethod<bool>('moveToBack') ?? false;
  }

  /// 推送计时配置给原生监控层。
  ///
  /// 仅 iOS 使用：Android 的配置走 `core` 通道（[TimeCore.configure]），
  /// Dart 仅在 `timeCore == null && monitor != null`（即 iOS 接线）时调用；
  /// iOS 原生据此持久化并调整 Screen Time 阈值事件与休息窗口时长。
  /// 其他平台未实现该方法，调用方需容忍 PlatformException。
  Future<void> configure(AppSettings settings) {
    return _channel.invokeMethod<void>('configure', <String, dynamic>{
      'quizSeconds': settings.quizInterval.inSeconds,
      'restSeconds': settings.restDuration.inSeconds,
      'dailyLimit': settings.dailyExemptionLimit,
      'restEnabled': settings.restEnabled,
      'exemptWindows': [
        for (final window in settings.exemptionWindows) window.toJson(),
      ],
    });
  }

  /// 查询安装包构建信息（版本号 + 产品风味 free / pro）。
  ///
  /// 非 Android 或原生未实现时返回 null，调用方沿用编译期默认值。
  Future<AppBuildInfo?> getAppInfo() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
    if (raw == null) return null;
    final flavor = raw['flavor'];
    final version = raw['version'];
    if (flavor is! String) return null;
    return AppBuildInfo(
      flavor: flavor,
      version: version is String ? version : '',
    );
  }
}

/// 原生上报的构建信息（Android `BuildConfig.FLAVOR` / `VERSION_NAME`）。
class AppBuildInfo {
  const AppBuildInfo({required this.flavor, required this.version});

  /// 产品风味：`free` 或 `pro`。
  final String flavor;

  /// 版本号（来自 pubspec 的 versionName）。
  final String version;
}

// ---------------------------------------------------------------------
// 到点干预
// ---------------------------------------------------------------------

/// 需要原生强制展示的阶段。
enum InterventionPhase {
  /// 到点答题（提醒/答题页）。
  quiz,

  /// 全屏强制休息。
  resting,
}

/// 干预桥抽象：测试可注入假实现，生产环境使用 [ChannelInterventionBridge]。
abstract class InterventionBridge {
  /// 请求原生把答题/休息界面拉到用户面前（全屏 intent、悬浮窗等）。
  Future<void> request(InterventionPhase phase);

  /// 回到计时阶段，通知原生撤销干预（取消通知、移除悬浮层）。
  Future<void> dismiss();

  // -- 休息期额外能力 --

  /// 调用 DevicePolicyManager.lockNow() 熄屏。
  /// 返回是否成功；未授权 Device Admin 时返回 false。
  Future<bool> lockScreen();

  /// 是否已授权 Device Admin（force-lock 策略）。
  Future<bool> get isDeviceAdminEnabled;

  /// 跳转到系统 Device Admin 授权页。
  Future<void> openDeviceAdminSettings();

  /// 进入屏幕固定模式（resting 阶段独占屏幕，防手动切任务）。
  Future<bool> startScreenPinning();

  /// 退出屏幕固定模式（resting → tracking 时调用）。
  Future<bool> stopScreenPinning();
}

/// 基于 MethodChannel `intervention` 的生产实现。
class ChannelInterventionBridge implements InterventionBridge {
  ChannelInterventionBridge({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('$kPlatformChannelNamespace/intervention');

  final MethodChannel _channel;

  @override
  Future<void> request(InterventionPhase phase) {
    return _channel.invokeMethod<void>(
      'request',
      <String, String>{'phase': phase.name},
    );
  }

  @override
  Future<void> dismiss() {
    return _channel.invokeMethod<void>('dismiss');
  }

  @override
  Future<bool> lockScreen() async {
    return await _channel.invokeMethod<bool>('lockScreen') ?? false;
  }

  @override
  Future<bool> get isDeviceAdminEnabled async {
    return await _channel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
  }

  @override
  Future<void> openDeviceAdminSettings() {
    return _channel.invokeMethod<void>('openDeviceAdminSettings');
  }

  @override
  Future<bool> startScreenPinning() async {
    return await _channel.invokeMethod<bool>('startScreenPinning') ?? false;
  }

  @override
  Future<bool> stopScreenPinning() async {
    return await _channel.invokeMethod<bool>('stopScreenPinning') ?? false;
  }
}

// ---------------------------------------------------------------------
// 原生权威计时核心
// ---------------------------------------------------------------------

/// 原生权威计时核心的对外快照。
///
/// 原生 `ScreenTimeCore` 始终是唯一计时源；Dart 每秒读取本快照镜像显示，
/// 用户操作经 [TimeCore] 回写原生。
class TimeCoreSnapshot {
  /// 今日累计亮屏时长。
  final Duration usedToday;

  /// 自上次豁免通过 / 休息结束以来的阈值进度。
  final Duration thresholdProgress;

  /// 今日已用豁免次数（状态机口径）。
  final int exemptionsUsedToday;

  /// 是否处于强制休息阶段。
  final bool resting;

  /// 休息截止时刻；不在休息期时为 null。
  final DateTime? restEndsAt;

  /// 进行中休息的起点；不在休息期时为 null。
  final DateTime? restStart;

  /// 屏幕当前是否点亮。
  final bool isScreenOn;

  /// 今日触发休息次数（含进行中）。
  final int restCount;

  /// 今日**已完成**休息的实际时长（不含进行中）。
  final Duration restCompleted;

  /// 今日休息期豁免次数。
  final int restExemptions;

  /// 原生是否已有当日数据（升级迁移判定用）。
  final bool hasDayData;

  /// 当日"远离手机"已完结累计时长（休息起点到休息结束/下次亮屏的片段和）。
  final Duration away;

  /// 进行中的"远离手机"挂起片段起点；无挂起时为 null。
  final DateTime? pendingAwayStart;

  const TimeCoreSnapshot({
    required this.usedToday,
    required this.thresholdProgress,
    required this.exemptionsUsedToday,
    required this.resting,
    required this.isScreenOn,
    required this.restCount,
    required this.restCompleted,
    required this.restExemptions,
    required this.hasDayData,
    this.restEndsAt,
    this.restStart,
    this.away = Duration.zero,
    this.pendingAwayStart,
  });

  /// 从通道返回的 Map 解析；毫秒为 0 的时刻字段映射为 null。
  factory TimeCoreSnapshot.fromMap(Map<String, dynamic> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    final restEndsAtMs = intOf('restEndsAtMs');
    final restStartMs = intOf('restStartMs');
    final pendingAwayStartMs = intOf('pendingAwayStartMs');
    return TimeCoreSnapshot(
      usedToday: Duration(seconds: intOf('screenTimeSec')),
      thresholdProgress: Duration(seconds: intOf('thresholdSec')),
      exemptionsUsedToday: intOf('exemptionsUsedToday'),
      resting: map['resting'] == true,
      restEndsAt: restEndsAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(restEndsAtMs)
          : null,
      restStart:
          restStartMs > 0 ? DateTime.fromMillisecondsSinceEpoch(restStartMs) : null,
      isScreenOn: map['isScreenOn'] == true,
      restCount: intOf('restCount'),
      restCompleted: Duration(seconds: intOf('restElapsedSec')),
      restExemptions: intOf('restExemptions'),
      hasDayData: map['hasDayData'] == true,
      away: Duration(seconds: intOf('awaySec')),
      pendingAwayStart: pendingAwayStartMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(pendingAwayStartMs)
          : null,
    );
  }
}

/// 权威计时核心抽象。
///
/// Android 走原生实现 [ChannelTimeCore]；桌面/Web/测试为 null，
/// 控制器退化为本地 Timer 驱动状态机（现有行为不变）。
abstract class TimeCore {
  /// 读取当前权威快照。
  Future<TimeCoreSnapshot> snapshot();

  /// 推送配置（阈值 / 休息时长 / 每日豁免上限 / 强制休息开关 /
  /// 豁免时间段），原生持久化。
  Future<void> configure(AppSettings settings);

  /// 手动触发休息（计时页"立即休息"）。
  Future<void> manualRest();

  /// 休息期答题豁免通过：消耗一次额度并结束休息。
  Future<void> consumeExemption();

  /// 升级迁移：原生无当日数据时用旧快照初始化，返回是否已写入。
  Future<bool> seedFromSnapshot({
    required Duration usedToday,
    required Duration thresholdProgress,
    required int exemptionsUsedToday,
    required bool resting,
    DateTime? restEndsAt,
  });
}

/// 基于 MethodChannel `core` 的生产实现。
class ChannelTimeCore implements TimeCore {
  ChannelTimeCore({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('$kPlatformChannelNamespace/core');

  final MethodChannel _channel;

  @override
  Future<TimeCoreSnapshot> snapshot() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('snapshot');
    return TimeCoreSnapshot.fromMap(raw ?? const <String, dynamic>{});
  }

  @override
  Future<void> configure(AppSettings settings) {
    return _channel.invokeMethod<void>('configure', <String, dynamic>{
      'quizSeconds': settings.quizInterval.inSeconds,
      'restSeconds': settings.restDuration.inSeconds,
      'dailyLimit': settings.dailyExemptionLimit,
      'restEnabled': settings.restEnabled,
      'exemptWindows': [
        for (final window in settings.exemptionWindows) window.toJson(),
      ],
    });
  }

  @override
  Future<void> manualRest() => _channel.invokeMethod<void>('manualRest');

  @override
  Future<void> consumeExemption() =>
      _channel.invokeMethod<void>('consumeExemption');

  @override
  Future<bool> seedFromSnapshot({
    required Duration usedToday,
    required Duration thresholdProgress,
    required int exemptionsUsedToday,
    required bool resting,
    DateTime? restEndsAt,
  }) async {
    return await _channel.invokeMethod<bool>('seedFromSnapshot',
            <String, dynamic>{
          'usedTodaySec': usedToday.inSeconds,
          'thresholdSec': thresholdProgress.inSeconds,
          'exemptionsUsed': exemptionsUsedToday,
          'resting': resting,
          'restEndsAtMs': restEndsAt?.millisecondsSinceEpoch ?? 0,
        }) ??
        false;
  }
}
