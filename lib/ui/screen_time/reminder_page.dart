/// 全屏提醒页：累计亮屏达到阈值后弹出，引导用户答题豁免或立即休息。
library;

import 'package:flutter/material.dart';

import 'quiz_page.dart';
import 'screen_time_controller.dart';

/// 全屏提醒页。
///
/// 展示当前已亮屏时长与阈值，提供两个出口：
/// - "继续使用"：首次豁免免费直接通过；其余轮次进入 [QuizPage] 答题。
/// - "立即休息"：放弃本轮答题，进入全屏休息。
class ReminderPage extends StatelessWidget {
  final ScreenTimeController controller;

  const ReminderPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 已点击"继续使用"且本轮需要答题：切换到答题页。
        if (controller.reminderShown) {
          return QuizPage(controller: controller);
        }
        final state = controller.machine.state;
        final isFirstFree = state.quizRound <= 1;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.timer_outlined,
                    size: 96,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '该休息一下了',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '你已连续亮屏 ${state.sinceLastGrant.inMinutes} 分钟',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFirstFree ? '首次提醒可直接继续使用' : '答题豁免即可继续使用',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: controller.continueUsage,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(isFirstFree ? '继续使用（免费）' : '继续使用（答题豁免）'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.giveUp,
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('立即休息'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
