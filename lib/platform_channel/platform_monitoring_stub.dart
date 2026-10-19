/// Web 平台的空监控接线：不提供任何通道，状态机保持 Timer 驱动。
///
/// 本文件禁止 import `dart:io`（Web 上 `Platform` 会抛
/// `Unsupported operation`）。
library;

import 'dart:async' show Stream;

import 'platform_channels.dart';

/// 空干预桥：桌面/Web/测试下所有方法静默 no-op，返回安全默认值。
class _NoopInterventionBridge implements InterventionBridge {
  const _NoopInterventionBridge();

  @override
  Future<void> request(InterventionPhase phase) async {}

  @override
  Future<void> dismiss() async {}

  @override
  Future<bool> lockScreen() async => false;

  @override
  Future<bool> get isDeviceAdminEnabled async => false;

  @override
  Future<void> openDeviceAdminSettings() async {}

  @override
  Future<bool> startScreenPinning() async => false;

  @override
  Future<bool> stopScreenPinning() async => false;
}

/// 当前平台的监控资源包（Web 下除 interventionBridge 外全部为 null）。
class PlatformMonitoring {
  /// 监控服务/权限通道。
  final MonitorChannel? monitor = null;

  /// 亮灭屏事件流。
  final Stream<bool>? screenOnEvents = null;

  /// 到点干预桥：Web 下返回空实现，所有调用静默 no-op。
  final InterventionBridge interventionBridge = const _NoopInterventionBridge();

  /// 原生权威计时核心：Web 下为 null，控制器走本地 Timer 驱动。
  final TimeCore? timeCore = null;

  /// 构造空接线。
  const PlatformMonitoring();
}

/// Web 下始终返回空接线。
PlatformMonitoring createPlatformMonitoring() => const PlatformMonitoring();
