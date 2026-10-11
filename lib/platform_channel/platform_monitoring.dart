/// 平台监控接线入口（条件导入）。
///
/// 与数据层一致采用条件导入做平台分流，避免 `dart:io` 进入 Web 编译：
/// - 原生平台（含桌面）→ `platform_monitoring_native.dart`，内部再用
///   `Platform.isAndroid` 收窄，仅 Android 返回真实通道，桌面返回空接线；
/// - Web → `platform_monitoring_stub.dart`，始终为空。
///
/// 空接线时 [ScreenTimeController] 退化为 Timer 驱动（桌面/Web/测试行为不变）。
library;

import 'platform_monitoring_native.dart'
    if (dart.library.js_interop) 'platform_monitoring_stub.dart' as impl;

// 条件导出 PlatformMonitoring 类型：Web 侧导出无 dart:io 的 stub，
// 与上方条件导入选择同一个文件，不会把 dart:io 带入 Web 编译。
// 注意：export 不会让类型在本库内可见，故下面的返回类型走 impl 前缀。
export 'platform_monitoring_native.dart'
    if (dart.library.js_interop) 'platform_monitoring_stub.dart';

/// 创建当前平台的监控资源包；非 Android 平台所有字段为 null。
impl.PlatformMonitoring createPlatformMonitoring() =>
    impl.createPlatformMonitoring();
