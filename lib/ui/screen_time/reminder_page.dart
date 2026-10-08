/// 全屏提醒页：累计亮屏达到阈值后弹出，引导用户答题豁免或立即休息。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
        final l10n = S.of(context);

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
                    l10n.reminderTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.reminderContinuous(state.sinceLastGrant.inMinutes),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFirstFree ? l10n.reminderFirstFree : l10n.reminderQuizToPass,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: controller.continueUsage,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(isFirstFree ? l10n.reminderContinueFree : l10n.reminderContinueQuiz),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.giveUp,
                    icon: const Icon(Icons.bedtime_outlined),
                    label: Text(l10n.reminderRestNow),
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
