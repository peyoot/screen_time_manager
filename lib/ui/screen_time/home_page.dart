/// 主计时页面：展示亮屏时长、豁免次数并提供手动休息入口。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../state_machine/app_phase.dart';
import '../../state_machine/screen_time_state.dart';
import '../question_bank/group_list_page.dart';
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
class _TimingView extends StatelessWidget {
  final ScreenTimeController controller;

  const _TimingView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.machine.state;
    final l10n = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.homeBankTooltip,
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupListPage(service: controller.bankService),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.homeSettingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _TimingSettingsDialog(controller: controller),
            ),
          ),
          IconButton(
            tooltip: l10n.homeLanguageTooltip,
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguagePicker(context, controller),
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
                  _TimeCard(state: state),
                  const SizedBox(height: 24),
                  _StatRow(
                    state: state,
                    remainingExemptions: controller.remainingExemptions,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: controller.manualRest,
                    icon: const Icon(Icons.bedtime_outlined),
                    label: Text(l10n.homeManualRest),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示语言选择底部弹窗。
  void _showLanguagePicker(BuildContext context, ScreenTimeController controller) {
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

  const _TimeCard({required this.state});

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
              l10n.homeNextQuizIn(_formatDuration(state.remainingToQuiz)),
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

/// 豁免次数与当前轮次统计行。
class _StatRow extends StatelessWidget {
  final ScreenTimeState state;
  final int remainingExemptions;

  const _StatRow({
    required this.state,
    required this.remainingExemptions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.check_circle_outline,
            label: l10n.homeExemptionsLeft,
            value: l10n.homeExemptionsCount(remainingExemptions),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            icon: Icons.notifications_active_outlined,
            label: l10n.homeReminderRound,
            value: l10n.homeRoundNth(state.quizRound),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
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
            Text(label, style: theme.textTheme.bodySmall),
            Text(value, style: theme.textTheme.titleLarge),
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
  late final TextEditingController _quizController;
  late final TextEditingController _restController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.machine.settings;
    _quizController =
        TextEditingController(text: '${settings.quizInterval.inMinutes}');
    _restController =
        TextEditingController(text: '${settings.restDuration.inMinutes}');
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
    if (quizMinutes == null ||
        restMinutes == null ||
        quizMinutes <= 0 ||
        restMinutes <= 0) {
      setState(() => _error = S.of(context).settingsInvalid);
      return;
    }
    widget.controller.updateTiming(
      quizMinutes: quizMinutes,
      restMinutes: restMinutes,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quizController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.settingsQuizMinutes,
              suffixText: l10n.settingsMinutesUnit,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _restController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.settingsRestMinutes,
              suffixText: l10n.settingsMinutesUnit,
            ),
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
        ],
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
