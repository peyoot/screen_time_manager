/// Web 平台的空监控接线：不提供任何通道，状态机保持 Timer 驱动。
///
/// 本文件禁止 import `dart:io`（Web 上 `Platform` 会抛
/// `Unsupported operation`）。
library;

import 'dart:async' show Stream;

import 'platform_channels.dart';

/// 当前平台的监控资源包（Web 下全部为 null）。
class PlatformMonitoring {
  /// 监控服务/权限通道。
  final MonitorChannel? monitor = null;

  /// 亮灭屏事件流。
  final Stream<bool>? screenOnEvents = null;

  /// 到点干预桥。
  final InterventionBridge? interventionBridge = null;

  /// 构造空接线。
  const PlatformMonitoring();
}

/// Web 下始终返回空接线。
PlatformMonitoring createPlatformMonitoring() => const PlatformMonitoring();
