/// Flutter ↔ Android 原生平台通道定义。
///
/// 所有通道共用命名空间 `com.screen_time_manager/platform`：
/// - EventChannel `screen_events`：原生 → Dart 的亮屏（true）/灭屏（false）事件；
/// - MethodChannel `monitor`：监控服务的启停控制与权限查询/跳转；
/// - MethodChannel `intervention`：Dart 进入答题/休息阶段时请求原生把界面拉到前台。
///
/// 本文件只依赖 `flutter/services`，不引入 `dart:io`，可在任意平台编译；
/// 是否真正接线由 [platform_monitoring] 的条件导入决定。
library;

import 'package:flutter/services.dart';

/// 通道统一命名空间。
const String kPlatformChannelNamespace = 'com.screen_time_manager/platform';

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
}
