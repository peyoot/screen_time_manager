/// 权限引导页：逐项展示监控运行所需的系统权限状态，点击跳转对应设置页。
///
/// 覆盖第 4 步的权限引导项：悬浮窗、通知、全屏 intent、电池优化白名单、
/// 无障碍服务与 OEM 自启动管理。自启动无公开状态 API，仅提供跳转。
/// 返回本页（从系统设置切回）时自动刷新各权限状态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import '../../l10n/app_localizations.dart';
import '../../platform_channel/platform_channels.dart';

/// 单个权限条目的静态描述（文案与图标不随运行时变化）。
class _PermissionEntry {
  final IconData icon;
  final String Function(S l10n) title;
  final String Function(S l10n) description;

  /// 需要查询/跳转的权限项；null 表示自启动（仅跳转）。
  final MonitorPermission? permission;

  const _PermissionEntry({
    required this.icon,
    required this.title,
    required this.description,
    this.permission,
  });
}

class PermissionGuidePage extends StatefulWidget {
  /// 监控/权限通道；null（非 Android 平台）时显示不可用提示。
  final MonitorChannel? monitor;

  const PermissionGuidePage({super.key, this.monitor});

  @override
  State<PermissionGuidePage> createState() => _PermissionGuidePageState();
}

class _PermissionGuidePageState extends State<PermissionGuidePage>
    with WidgetsBindingObserver {
  static const _entries = <_PermissionEntry>[
    _PermissionEntry(
      icon: Icons.layers_outlined,
      title: _permOverlayTitle,
      description: _permOverlayDesc,
      permission: MonitorPermission.overlay,
    ),
    _PermissionEntry(
      icon: Icons.notifications_outlined,
      title: _permNotificationsTitle,
      description: _permNotificationsDesc,
      permission: MonitorPermission.notifications,
    ),
    _PermissionEntry(
      icon: Icons.fullscreen_outlined,
      title: _permFullScreenTitle,
      description: _permFullScreenDesc,
      permission: MonitorPermission.fullScreenIntent,
    ),
    _PermissionEntry(
      icon: Icons.battery_saver_outlined,
      title: _permBatteryTitle,
      description: _permBatteryDesc,
      permission: MonitorPermission.ignoreBatteryOptimizations,
    ),
    _PermissionEntry(
      icon: Icons.alarm_outlined,
      title: _permExactAlarmTitle,
      description: _permExactAlarmDesc,
      permission: MonitorPermission.exactAlarm,
    ),
    _PermissionEntry(
      icon: Icons.accessibility_new_outlined,
      title: _permAccessibilityTitle,
      description: _permAccessibilityDesc,
      permission: MonitorPermission.accessibility,
    ),
    _PermissionEntry(
      icon: Icons.screen_lock_portrait_outlined,
      title: _permDeviceAdminTitle,
      description: _permDeviceAdminDesc,
      permission: MonitorPermission.deviceAdmin,
    ),
    _PermissionEntry(
      icon: Icons.restart_alt_outlined,
      title: _permAutoStartTitle,
      description: _permAutoStartDesc,
      // 自启动无公开状态 API，仅提供跳转。
    ),
  ];

  /// 各权限当前状态；未查询到（非 Android/通道异常）时为空表。
  Map<MonitorPermission, bool> _status = const {};

  /// 通道调用是否失败（非 Android 平台或通道未注册）。
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置页返回本页时刷新权限状态。
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final monitor = widget.monitor;
    // 非 Android 平台（无通道）：直接显示不可用提示，不渲染无状态的空列表。
    if (monitor == null) {
      if (mounted) setState(() => _unavailable = true);
      return;
    }
    try {
      final status = await monitor.getPermissions();
      if (mounted) {
        setState(() {
          _status = status;
          _unavailable = false;
        });
      }
    } on MissingPluginException {
      if (mounted) setState(() => _unavailable = true);
    } on PlatformException {
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<void> _openSettings(MonitorPermission permission) async {
    try {
      await widget.monitor?.openPermissionSettings(permission);
    } on MissingPluginException {
      // 非 Android 平台：无设置页可跳。
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.permGuideTitle)),
      body: _unavailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.permUnavailable,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildTile(context, theme, _entries[index]),
            ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    ThemeData theme,
    _PermissionEntry entry,
  ) {
    final l10n = S.of(context);
    final granted = entry.permission == null ? null : _status[entry.permission!];
    return ListTile(
      leading: Icon(
        entry.icon,
        color: granted == false ? theme.colorScheme.error : null,
      ),
      title: Text(entry.title(l10n)),
      subtitle: Text(entry.description(l10n)),
      isThreeLine: true,
      trailing: _buildTrailing(theme, granted),
      onTap: entry.permission == null
          ? () => _openSettings(MonitorPermission.autoStart)
          : () => _openSettings(entry.permission!),
    );
  }

  /// 条目右侧状态：已授予（绿色对勾）/ 未授予（红色关闭）/ 仅跳转（箭头）。
  Widget _buildTrailing(ThemeData theme, bool? granted) {
    final l10n = S.of(context);
    switch (granted) {
      case true:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.permGranted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
          ],
        );
      case false:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.permDenied,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.cancel, color: theme.colorScheme.error, size: 20),
          ],
        );
      default:
        return const Icon(Icons.chevron_right);
    }
  }
}

// 文案取值函数（避免每个条目重复写 lambda 签名）。
String _permOverlayTitle(S l10n) => l10n.permOverlayTitle;
String _permOverlayDesc(S l10n) => l10n.permOverlayDesc;
String _permNotificationsTitle(S l10n) => l10n.permNotificationsTitle;
String _permNotificationsDesc(S l10n) => l10n.permNotificationsDesc;
String _permFullScreenTitle(S l10n) => l10n.permFullScreenTitle;
String _permFullScreenDesc(S l10n) => l10n.permFullScreenDesc;
String _permBatteryTitle(S l10n) => l10n.permBatteryTitle;
String _permBatteryDesc(S l10n) => l10n.permBatteryDesc;
String _permExactAlarmTitle(S l10n) => l10n.permExactAlarmTitle;
String _permExactAlarmDesc(S l10n) => l10n.permExactAlarmDesc;
String _permAccessibilityTitle(S l10n) => l10n.permAccessibilityTitle;
String _permAccessibilityDesc(S l10n) => l10n.permAccessibilityDesc;
String _permDeviceAdminTitle(S l10n) => l10n.permDeviceAdminTitle;
String _permDeviceAdminDesc(S l10n) => l10n.permDeviceAdminDesc;
String _permAutoStartTitle(S l10n) => l10n.permAutoStartTitle;
String _permAutoStartDesc(S l10n) => l10n.permAutoStartDesc;
