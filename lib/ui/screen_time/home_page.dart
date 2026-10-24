/// 主计时页面：展示亮屏时长、豁免次数并提供手动休息入口。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../state_machine/app_phase.dart';
import '../../state_machine/screen_time_state.dart';
import '../question_bank/group_list_page.dart';
import '../about/about_page.dart';
import '../permissions/permission_guide_page.dart';
import 'admin_password_dialogs.dart';
import 'reminder_page.dart';
import 'rest_page.dart';
import 'screen_time_controller.dart';

/// 主计时页，根据控制器阶段切换展示内容。
class HomePage extends StatelessWidget {
  final ScreenTimeController controller;

  const HomePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        // 全屏阶段使用独立页面视图，便于沉浸式展示。
        if (phase == AppPhase.quiz) {
          return ReminderPage(controller: controller);
        }
        if (phase == AppPhase.resting) {
          return RestPage(controller: controller);
        }
        return _TimingView(controller: controller);
      },
    );
  }
}

/// 计时阶段的主体视图。
///
/// 提供手动休息入口以及一个"退到后台"按钮：
/// - 点击立即退居后台（不销毁进程，监控/计时继续）；
/// - 按钮显示 15 秒倒计时，期间无操作则自动退到后台；
/// - 点击页面任意处（打开设置/题库/权限等）会重置倒计时，避免误退。
///
/// 背景：部分国产 ROM（如 ZUXOS）划掉应用后无法自动重启，因此提供
/// 显式"退到后台"替代划卡，保证进程存活。
class _TimingView extends StatefulWidget {
  final ScreenTimeController controller;

  const _TimingView({required this.controller});

  @override
  State<_TimingView> createState() => _TimingViewState();
}

class _TimingViewState extends State<_TimingView>
    with WidgetsBindingObserver {
  /// 无操作自动退到后台的倒计时秒数。
  static const int _autoExitSeconds = 15;

  int _remaining = _autoExitSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回到前台时重置倒计时。
    if (state == AppLifecycleState.resumed) {
      _resetCountdown();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      // 对话框/其他页面在前台时不自动退后台，保持倒计时满值等待用户返回。
      if (route != null && !route.isCurrent) {
        _resetCountdown();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        unawaited(widget.controller.moveToBackground());
      }
    });
  }

  void _resetCountdown() {
    if (mounted) setState(() => _remaining = _autoExitSeconds);
  }

  /// 用户点击退出按钮：立即退到后台。
  void _exitNow() {
    _timer?.cancel();
    unawaited(widget.controller.moveToBackground());
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.machine.state;
    final l10n = S.of(context);
    return Listener(
      // 点击页面任意处（设置/题库/手动休息等）重置倒计时，视为"有操作"。
      onPointerDown: (_) => _resetCountdown(),
      child: Scaffold(
        appBar: AppBar(
          // 窄屏时自动缩小字号，保证完整应用名不被右侧按钮截断。
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(l10n.appTitle),
          ),
          actions: [
            IconButton(
              tooltip: l10n.homePermissionsTooltip,
              icon: const Icon(Icons.verified_user_outlined),
              // 权限与保活设置同样需要管理密码，防止儿童自行关闭保活/干预权限。
              onPressed: () => openWithAdminGate(context, widget.controller, () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PermissionGuidePage(monitor: widget.controller.monitor),
                  ),
                );
              }),
            ),
            IconButton(
              tooltip: l10n.homeBankTooltip,
              icon: const Icon(Icons.quiz_outlined),
              // 已设置管理密码时，题库（含答案）需先验证才能进入。
              onPressed: () => openWithAdminGate(context, widget.controller, () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GroupListPage(service: widget.controller.bankService),
                  ),
                );
              }),
            ),
            IconButton(
              tooltip: l10n.homeSettingsTooltip,
              icon: const Icon(Icons.settings_outlined),
              // 已设置管理密码时，进入设置需先验证。
              onPressed: () => openWithAdminGate(context, widget.controller, () {
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _TimingSettingsDialog(controller: widget.controller),
                );
              }),
            ),
            IconButton(
              tooltip: l10n.homeLanguageTooltip,
              icon: const Icon(Icons.language),
              onPressed: () => _showLanguagePicker(context, widget.controller),
            ),
            IconButton(
              tooltip: l10n.homeAboutTooltip,
              icon: const Icon(Icons.info_outline),
              // 关于页：版本号、Free / Pro 配额、许可与帮助入口。
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // 内容不足一屏时按钮仍贴底；超出时可滚动，避免短视口溢出。
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    _TimeCard(
                      state: state,
                      restEnabled:
                          widget.controller.machine.settings.restEnabled,
                    ),
                    const SizedBox(height: 24),
                    _StatRow(
                      remainingExemptions: widget.controller.remainingExemptions,
                      restExemptions: widget.controller.todayRestExemptions,
                      restCount: widget.controller.todayRestCount,
                      away: widget.controller.todayAwayDuration,
                    ),
                    const Spacer(),
                    // 强制休息关闭时不提供手动休息入口（无任何休息/锁屏行为）。
                    if (widget.controller.machine.settings.restEnabled)
                      FilledButton.icon(
                        onPressed: widget.controller.manualRest,
                        icon: const Icon(Icons.bedtime_outlined),
                        label: Text(l10n.homeManualRest),
                      ),
                    const SizedBox(height: 12),
                    // 显眼的"退到后台"按钮：点击立即退后台，显示倒计时，
                    // 15 秒无操作自动退后台。
                    OutlinedButton.icon(
                      onPressed: _exitNow,
                      icon: const Icon(Icons.exit_to_app),
                      label: Text(
                        l10n.homeExitToBackgroundCountdown(_remaining),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeExitAutoHint(_remaining),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示语言选择底部弹窗。
  void _showLanguagePicker(
      BuildContext context, ScreenTimeController controller) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = S.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.homeLanguageTooltip),
                leading: const Icon(Icons.language),
              ),
              const Divider(),
              ...[
                (null, '跟随系统'),
                (const Locale('zh'), '中文'),
                (const Locale('en'), 'English'),
                (const Locale('ja'), '日本語'),
                (const Locale('ko'), '한국어'),
              ].map((entry) {
                final (locale, name) = entry;
                return ListTile(
                  title: Text(name),
                  trailing: controller.localeController.locale == locale
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    controller.localeController.setLocale(locale);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// 大号时长展示卡片。
class _TimeCard extends StatelessWidget {
  final ScreenTimeState state;

  /// 强制休息是否启用：关闭时第二行显示"强制休息未启用"。
  final bool restEnabled;

  const _TimeCard({required this.state, required this.restEnabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Text(l10n.homeTodayScreenTime, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              _formatDuration(state.usedToday),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              restEnabled
                  ? l10n.homeNextQuizIn(
                      _formatDuration(state.remainingToQuiz))
                  : l10n.homeRestDisabled,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 豁免与当日休息统计行：左右两张双行卡片。
class _StatRow extends StatelessWidget {
  final int remainingExemptions;
  final int restExemptions;
  final int restCount;
  final Duration away;

  const _StatRow({
    required this.remainingExemptions,
    required this.restExemptions,
    required this.restCount,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _TwoLineStatCard(
            icon: Icons.check_circle_outline,
            line1: l10n.homeRoundExemptions(remainingExemptions),
            line2: l10n.homeRestExemptionsToday(restExemptions),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TwoLineStatCard(
            icon: Icons.bedtime_outlined,
            line1: l10n.homeRestTriggeredToday(restCount),
            line2: l10n.homeAwaySaved(_formatDuration(away)),
          ),
        ),
      ],
    );
  }
}

/// 双行统计卡片：图标 + 两行数据（窄屏自动缩放防溢出）。
class _TwoLineStatCard extends StatelessWidget {
  final IconData icon;
  final String line1;
  final String line2;

  const _TwoLineStatCard({
    required this.icon,
    required this.line1,
    required this.line2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(line1, style: theme.textTheme.bodyMedium),
            ),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(line2, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// 将 [Duration] 格式化为 HH:MM:SS。
String _formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// 计时设置对话框：修改亮屏触发时长与强制休息时长（分钟）。
///
/// 打开时预填当前配置；两个字段都必须是正整数，否则在对话框内提示错误，
/// 不会调用状态机更新。
class _TimingSettingsDialog extends StatefulWidget {
  final ScreenTimeController controller;

  const _TimingSettingsDialog({required this.controller});

  @override
  State<_TimingSettingsDialog> createState() => _TimingSettingsDialogState();
}

class _TimingSettingsDialogState extends State<_TimingSettingsDialog> {
  /// 休息页秒表刷新间隔的可选值（毫秒）。
  static const List<int> _refreshOptions = [1, 7, 13, 17, 31, 57];

  late final TextEditingController _quizController;
  late final TextEditingController _restController;
  late int _refreshMs;
  late bool _restEnabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.machine.settings;
    _quizController =
        TextEditingController(text: '${settings.quizInterval.inMinutes}');
    _restController =
        TextEditingController(text: '${settings.restDuration.inMinutes}');
    _refreshMs = settings.restTimerRefreshMs;
    _restEnabled = settings.restEnabled;
  }

  @override
  void dispose() {
    _quizController.dispose();
    _restController.dispose();
    super.dispose();
  }

  void _save() {
    final quizMinutes = int.tryParse(_quizController.text.trim());
    final restMinutes = int.tryParse(_restController.text.trim());
    // 亮屏触发时长上限 300 分钟，强制休息时长上限 99 分钟。
    if (quizMinutes == null || quizMinutes <= 0 || quizMinutes > 300) {
      setState(() => _error = S.of(context).settingsInvalidQuiz);
      return;
    }
    if (restMinutes == null || restMinutes <= 0 || restMinutes > 99) {
      setState(() => _error = S.of(context).settingsInvalid);
      return;
    }
    widget.controller.updateTiming(
      quizMinutes: quizMinutes,
      restMinutes: restMinutes,
      restTimerRefreshMs: _refreshMs,
      restEnabled: _restEnabled,
    );
    Navigator.of(context).pop();
  }

  /// 设置/修改管理密码：弹出双字段对话框，返回后刷新状态显示。
  Future<void> _editAdminPassword() async {
    await showSetAdminPasswordDialog(context, widget.controller);
    setState(() {});
  }

  /// 清除管理密码（当前已在通过门禁的设置对话框内，无需二次验证）。
  void _clearAdminPassword() {
    widget.controller.updateAdminPassword(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final hasPassword = widget.controller.hasAdminPassword;
    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 强制休息总开关：关闭后只统计亮屏时长，
            // 到点不触发休息、主页隐藏手动休息入口。
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsRestEnabled),
              subtitle: Text(l10n.settingsRestEnabledHint),
              value: _restEnabled,
              onChanged: (value) => setState(() => _restEnabled = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quizController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              decoration: InputDecoration(
                labelText: l10n.settingsQuizMinutes,
                suffixText: l10n.settingsMinutesUnit,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              decoration: InputDecoration(
                labelText: l10n.settingsRestMinutes,
                suffixText: l10n.settingsMinutesUnit,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            // 休息秒表刷新间隔：默认 17ms，可调低提高刷新率或调高降低功耗。
            // InputBorder.none 去掉输入装饰自带的下划线（删除提示词后残留）。
            DropdownButtonFormField<int>(
              initialValue: _refreshMs,
              decoration: InputDecoration(
                labelText: l10n.settingsRestTimerRefresh,
                border: InputBorder.none,
              ),
              items: [
                for (final ms in _refreshOptions)
                  DropdownMenuItem<int>(
                    value: ms,
                    child: Text('$ms ms'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _refreshMs = value);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const Divider(height: 24),
            // 管理密码区块：显示状态并提供设置/修改/清除入口。
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.adminPasswordTitle} · '
                    '${hasPassword ? l10n.adminPasswordStatusSet : l10n.adminPasswordStatusNotSet}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (hasPassword) ...[
                  TextButton(
                    onPressed: _editAdminPassword,
                    child: Text(l10n.adminPasswordChangeAction),
                  ),
                  TextButton(
                    onPressed: _clearAdminPassword,
                    child: Text(l10n.adminPasswordClearAction),
                  ),
                ] else
                  TextButton(
                    onPressed: _editAdminPassword,
                    child: Text(l10n.adminPasswordSetAction),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bankCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
      ],
    );
  }
}
