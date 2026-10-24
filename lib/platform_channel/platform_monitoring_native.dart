/// 原生平台（Android / iOS / HarmonyOS / 桌面）的监控接线。
///
/// - Android：完整接线（亮灭屏事件流 + 干预桥 + 原生权威计时核心）。
/// - iOS：仅 monitor / intervention 通道。iOS 无法监听全局亮灭屏、
///   也无法在后台持续 tick（应用被挂起），因此无 screenOnEvents、
///   timeCore 为 null——计时由 Dart Timer 驱动（仅应用存活期间有效），
///   到点后的"屏蔽受限应用"由原生 Screen Time API（ManagedSettings /
///   DeviceActivityMonitor 扩展）负责。
/// - HarmonyOS：与 Android 同构的全量接线（轮询式亮灭屏事件流 +
///   干预桥 + 原生权威计时核心）。Flutter-OH 的 `Platform.operatingSystem`
///   为 `ohos`；长时任务保活 + 每秒轮询驱动原生核心，Dart 仅作镜像。
/// - 桌面调试：空接线，继续使用 Timer 驱动状态机。
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

  /// 原生权威计时核心；null（非 Android）时控制器走本地 Timer 驱动。
  final TimeCore? timeCore;

  const PlatformMonitoring({
    this.monitor,
    this.screenOnEvents,
    this.interventionBridge,
    this.timeCore,
  });
}

/// 创建平台监控资源包：Android 全量接线，iOS 仅 monitor + intervention。
PlatformMonitoring createPlatformMonitoring() {
  if (Platform.isAndroid) {
    final monitor = MonitorChannel();
    return PlatformMonitoring(
      monitor: monitor,
      screenOnEvents: ScreenEventStream().events(),
      interventionBridge: ChannelInterventionBridge(),
      timeCore: ChannelTimeCore(),
    );
  }
  if (Platform.isIOS) {
    // iOS 无全局亮灭屏事件、无后台秒级计时能力：
    // 计时保持 Dart Timer 驱动，干预（屏蔽受限应用）走原生通道。
    return PlatformMonitoring(
      monitor: MonitorChannel(),
      interventionBridge: ChannelInterventionBridge(),
    );
  }
  if (Platform.operatingSystem == 'ohos') {
    // HarmonyOS：与 Android 同构——原生权威计时核心（ArkTS）由长时任务
    // 驱动每秒轮询屏幕状态，Dart 仅作 UI 镜像；干预退化为通知 + wantAgent。
    final monitor = MonitorChannel();
    return PlatformMonitoring(
      monitor: monitor,
      screenOnEvents: ScreenEventStream().events(),
      interventionBridge: ChannelInterventionBridge(),
      timeCore: ChannelTimeCore(),
    );
  }
  return const PlatformMonitoring();
}
