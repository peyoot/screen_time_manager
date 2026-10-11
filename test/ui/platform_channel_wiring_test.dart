/// ScreenTimeController 的平台接线测试：
/// - 亮灭屏事件流驱动状态机（灭屏不累计亮屏时长）；
/// - 阶段变为 quiz/resting 时调用干预桥 request，回到计时调用 dismiss。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/platform_channel/platform_channels.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';
import 'package:screen_time_manager/state_machine/app_phase.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';
import 'package:screen_time_manager/ui/screen_time/screen_time_controller.dart';

/// 记录调用的假干预桥。
class _RecordingInterventionBridge implements InterventionBridge {
  final List<InterventionPhase> requests = [];
  int dismissCount = 0;

  @override
  Future<void> request(InterventionPhase phase) async {
    requests.add(phase);
  }

  @override
  Future<void> dismiss() async {
    dismissCount++;
  }
}

/// 构造带 1 道输入题的题库服务（满足控制器抽题需要）。
QuestionBankService _bankWithOneQuestion() {
  final service = QuestionBankService();
  service.importIntoNewGroup(
    name: 'g',
    questions: [
      BankQuestion(question: 'What is water?', answer: 'H2O'),
    ],
  );
  return service;
}

void main() {
  group('平台亮灭屏事件', () {
    test('灭屏事件切换状态机标志，且灭屏期间 tick 不累计亮屏时长', () async {
      var now = DateTime(2026, 10, 11, 9, 0);
      final machine = ScreenTimeMachine(
        settings: AppSettings(
          quizInterval: const Duration(minutes: 30),
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: const Duration(minutes: 3),
        ),
        clock: () => now,
        initiallyScreenOn: true,
      );
      final events = StreamController<bool>();
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        screenOnEvents: events.stream,
        autoStart: false,
      );
      addTearDown(() {
        controller.dispose();
        return events.close();
      });

      // 构造后初始为亮屏。
      expect(machine.state.isScreenOn, isTrue);

      // 灭屏：标志翻转，推进 60 秒不计亮屏时长。
      events.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isScreenOn, isFalse);

      now = now.add(const Duration(seconds: 60));
      machine.tick();
      expect(machine.state.usedToday, Duration.zero);

      // 重新亮屏：标志恢复，之后推进的时间正常累计。
      events.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isScreenOn, isTrue);

      now = now.add(const Duration(seconds: 60));
      machine.tick();
      expect(machine.state.usedToday, const Duration(seconds: 60));
    });
  });

  group('到点干预桥', () {
    test('手动休息触发 resting 干预，答题豁免提前结束后 dismiss', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = ScreenTimeMachine(
        settings: AppSettings(
          quizInterval: const Duration(minutes: 30),
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: const Duration(minutes: 3),
        ),
        clock: () => now,
        initiallyScreenOn: true,
      );
      final bridge = _RecordingInterventionBridge();
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        interventionBridge: bridge,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      machine.restNow();
      expect(machine.state.phase, AppPhase.resting);
      expect(bridge.requests, [InterventionPhase.resting]);
      expect(bridge.dismissCount, 0);

      // 额度充足，答题豁免提前结束休息 → 回到计时并撤销干预。
      machine.endRestEarly();
      expect(machine.state.phase, AppPhase.tracking);
      expect(bridge.dismissCount, 1);
    });

    test('累计亮屏达阈值触发 quiz 干预，答对达标后 dismiss', () {
      var now = DateTime(2026, 10, 11, 9, 0);
      final machine = ScreenTimeMachine(
        settings: AppSettings(
          quizInterval: const Duration(seconds: 1),
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: const Duration(minutes: 3),
        ),
        questionBank: QuestionBank(
          id: 'mcq',
          name: 'mcq',
          questions: const [
            Question(
              id: 'mq1',
              prompt: 'pick the right one',
              options: ['wrong', 'right'],
              correctIndex: 1,
            ),
          ],
        ),
        clock: () => now,
        initiallyScreenOn: true,
      );
      final bridge = _RecordingInterventionBridge();
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        interventionBridge: bridge,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      // 推进 2 秒（阈值 1 秒），触发答题。
      now = now.add(const Duration(seconds: 2));
      machine.tick();
      expect(machine.state.phase, AppPhase.quiz);
      expect(bridge.requests, [InterventionPhase.quiz]);
      expect(bridge.dismissCount, 0);

      // 答对唯一一题：豁免通过，回到计时并撤销干预。
      final current = machine.state.quiz!.currentQuestion!;
      machine.answerCurrentQuestion(current.correctIndex);
      expect(machine.state.phase, AppPhase.tracking);
      expect(bridge.dismissCount, 1);
    });

    test('未注入干预桥时阶段变化不抛错（桌面/Web/测试退化路径）', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = ScreenTimeMachine(
        settings: AppSettings(
          quizInterval: const Duration(minutes: 30),
          questionsPerQuiz: 1,
          requiredCorrectCount: 1,
          restDuration: const Duration(minutes: 3),
        ),
        clock: () => now,
        initiallyScreenOn: true,
      );
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      expect(() => machine.restNow(), returnsNormally);
      expect(() => machine.endRestEarly(), returnsNormally);
      expect(machine.state.phase, AppPhase.tracking);
    });
  });
}
