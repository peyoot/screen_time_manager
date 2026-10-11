/// 原生平台（Android / iOS / 桌面）的监控接线。
///
/// 当前仅 Android 返回真实通道；其他平台（含桌面调试）返回空接线，
/// 继续使用 Timer 驱动状态机。
library;

import 'dart:async' show Stream;
import 'dart:io' show Platform;

import 'platform_channels.dart';

/// 当前平台的监控资源包。
class PlatformMonitoring {
  /// 监控服务/权限通道；null 表示当前平台不支持。
  final MonitorChannel? monitor;

  /// 亮灭屏事件流；null 时控制器不接收平台屏幕事件。
  final Stream<bool>? screenOnEvents;

  /// 到点干预桥；null 时阶段变化不通知原生。
  final InterventionBridge? interventionBridge;

  const PlatformMonitoring({
    this.monitor,
    this.screenOnEvents,
    this.interventionBridge,
  });
}

/// 创建平台监控资源包：仅 Android 接线 MethodChannel/EventChannel。
PlatformMonitoring createPlatformMonitoring() {
  if (!Platform.isAndroid) return const PlatformMonitoring();
  final monitor = MonitorChannel();
  return PlatformMonitoring(
    monitor: monitor,
    screenOnEvents: ScreenEventStream().events(),
    interventionBridge: ChannelInterventionBridge(),
  );
}
