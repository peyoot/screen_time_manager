import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/state_machine/app_phase.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';

void main() {
  // 所有题目正确答案固定为下标 1，便于测试中精确控制对错。
  QuestionBank buildBank(int n, {String prefix = 'q'}) {
    return QuestionBank(
      id: 'bank',
      name: '测试题库',
      questions: [
        for (var i = 0; i < n; i++)
          Question(
            id: '$prefix$i',
            prompt: '题目 $i',
            options: const ['错误项', '正确项', '干扰项'],
            correctIndex: 1,
          ),
      ],
    );
  }

  late DateTime clock;
  late List<AppPhase> phaseLog;

  ScreenTimeMachine buildMachine({
    AppSettings? settings,
    QuestionBank? bank,
    bool initiallyScreenOn = true,
    int seed = 42,
  }) {
    final machine = ScreenTimeMachine(
      settings: settings ?? AppSettings.defaults,
      questionBank: bank ?? buildBank(10),
      clock: () => clock,
      random: Random(seed),
      initiallyScreenOn: initiallyScreenOn,
    );
    machine.addListener(() => phaseLog.add(machine.state.phase));
    return machine;
  }

  /// 推进虚拟时钟并触发一次 tick。
  void advance(ScreenTimeMachine m, Duration d) {
    clock = clock.add(d);
    m.tick();
  }

  setUp(() {
    clock = DateTime(2026, 10, 7, 8, 0);
    phaseLog = [];
  });

  group('初始状态与亮屏计时', () {
    test('初始为计时阶段、零用量', () {
      final m = buildMachine();
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.usedToday, Duration.zero);
      expect(m.state.sinceLastGrant, Duration.zero);
      expect(m.state.isScreenOn, isTrue);
      expect(m.state.remainingToQuiz, AppSettings.defaults.quizInterval);
      expect(m.state.quiz, isNull);
    });

    test('亮屏期间 tick 累计用量，灭屏不累计', () {
      final m = buildMachine(initiallyScreenOn: true);
      advance(m, const Duration(minutes: 10));
      expect(m.state.usedToday, const Duration(minutes: 10));
      expect(m.state.sinceLastGrant, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.tracking);

      m.setScreenOn(false);
      advance(m, const Duration(hours: 2));
      expect(m.state.usedToday, const Duration(minutes: 10));
      expect(m.state.sinceLastGrant, const Duration(minutes: 10));

      // 灭屏期间未 tick：再次亮屏后不能把灭屏时长误计入。
      clock = clock.add(const Duration(hours: 5));
      m.setScreenOn(true);
      m.tick();
      expect(m.state.usedToday, const Duration(minutes: 10));

      advance(m, const Duration(minutes: 5));
      expect(m.state.usedToday, const Duration(minutes: 15));
    });

    test('setScreenOn 重复设置同一值不触发通知', () {
      final m = buildMachine();
      expect(phaseLog, isEmpty);
      m.setScreenOn(true);
      expect(phaseLog, isEmpty);
    });
  });

  group('触发豁免答题', () {
    test('累计达到阈值进入答题阶段并按配置抽题', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 30),
        questionsPerQuiz: 3,
        requiredCorrectCount: 2,
        restDuration: const Duration(minutes: 3),
      );
      final m = buildMachine(settings: settings);

      advance(m, const Duration(minutes: 29, seconds: 59));
      expect(m.state.phase, AppPhase.tracking);

      advance(m, const Duration(seconds: 2));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.quizRound, 1);
      expect(m.state.quiz!.questions.length, 3);
      expect(m.state.restEndsAt, isNull);
    });

    test('阈值刚好达到时触发', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.quiz!.questions.length, 1);
    });

    test('答题阶段 tick 不计任何时长', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      final before = m.state.usedToday;
      advance(m, const Duration(hours: 1));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.usedToday, before);
    });
  });

  group('答题结果流转', () {
    test('答对达标：豁免通过并重新累计阈值', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.quiz);

      m.answerCurrentQuestion(1); // 正确
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.quiz, isNull);
      expect(m.state.sinceLastGrant, Duration.zero);
      expect(m.state.usedToday, const Duration(minutes: 30));

      // 再累计一个间隔才会触发第二轮。
      advance(m, const Duration(minutes: 29));
      expect(m.state.phase, AppPhase.tracking);
      advance(m, const Duration(minutes: 1));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.quizRound, 2);
    });

    test('答错题数在容忍范围内仍可通过（3 题需答对 2 题）', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 5),
        questionsPerQuiz: 3,
        requiredCorrectCount: 2,
        restDuration: const Duration(minutes: 3),
      );
      final m = buildMachine(settings: settings);
      advance(m, const Duration(minutes: 5));
      expect(m.state.phase, AppPhase.quiz);

      m.answerCurrentQuestion(1); // 对
      m.answerCurrentQuestion(0); // 错
      m.answerCurrentQuestion(1); // 对
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.quiz, isNull);
    });

    test('答对数不足进入全屏休息，休息结束回到计时', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 5),
        questionsPerQuiz: 2,
        requiredCorrectCount: 2,
        restDuration: const Duration(minutes: 3),
      );
      final m = buildMachine(settings: settings);
      advance(m, const Duration(minutes: 5));

      m.answerCurrentQuestion(1); // 对
      m.answerCurrentQuestion(0); // 错 → 休息
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.quiz, isNull);
      expect(
        m.state.restEndsAt,
        clock.add(const Duration(minutes: 3)),
      );

      // 休息期间（屏幕仍点亮）不计亮屏时长。
      advance(m, const Duration(minutes: 2, seconds: 59));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.usedToday, const Duration(minutes: 5));

      // 到达结束时刻回到计时，阈值重新累计。
      advance(m, const Duration(seconds: 1));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.restEndsAt, isNull);
      expect(m.state.sinceLastGrant, Duration.zero);

      // 休息结束后的余量已计入新一轮时长（本 tick 无余量）。
      advance(m, const Duration(minutes: 5));
      expect(m.state.phase, AppPhase.quiz);
    });

    test('休息结束 tick 的超出余量会计入新一轮时长', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 5),
        questionsPerQuiz: 1,
        requiredCorrectCount: 1,
        restDuration: const Duration(minutes: 3),
      );
      final m = buildMachine(settings: settings);
      advance(m, const Duration(minutes: 5));
      m.answerCurrentQuestion(0); // 答错 → 休息 3 分钟

      // 一次性跳过 8 分钟：3 分钟休息 + 5 分钟新一轮亮屏，
      // 应在同一个 tick 内再次触发答题。
      advance(m, const Duration(minutes: 8));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.quizRound, 2);
      expect(m.state.usedToday, const Duration(minutes: 10));
    });

    test('放弃答题直接进入休息', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      m.giveUpQuiz();
      expect(m.state.phase, AppPhase.resting);
      expect(
        m.state.restEndsAt,
        clock.add(const Duration(minutes: 3)),
      );

      advance(m, const Duration(minutes: 3));
      expect(m.state.phase, AppPhase.tracking);
    });

    test('非答题阶段作答/放弃抛出 StateError', () {
      final m = buildMachine();
      expect(() => m.answerCurrentQuestion(1), throwsStateError);
      expect(m.giveUpQuiz, throwsStateError);
    });

    test('休息期间可通过 endRestEarly 提前结束休息', () {
      final m = buildMachine();
      m.restNow();
      expect(m.state.phase, AppPhase.resting);

      m.endRestEarly();
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.restEndsAt, isNull);
      expect(m.state.sinceLastGrant, Duration.zero);
    });

    test('非休息阶段调用 endRestEarly 抛出 StateError', () {
      final m = buildMachine();
      expect(m.endRestEarly, throwsStateError);
    });
  });

  group('题库缺失', () {
    test('未配置题库时达到阈值直接进入休息', () {
      // 直接构造，绕过 buildMachine 中“非空默认题库”的便捷行为。
      final m = ScreenTimeMachine(
        settings: AppSettings.defaults,
        questionBank: null,
        clock: () => clock,
        initiallyScreenOn: true,
      );
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.quiz, isNull);
    });

    test('题库题量不足时进入休息，补够题量后下一轮正常答题', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 10),
        questionsPerQuiz: 5,
        requiredCorrectCount: 5,
        restDuration: const Duration(minutes: 1),
      );
      final m = buildMachine(settings: settings, bank: buildBank(2));
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.resting);

      advance(m, const Duration(minutes: 1)); // 休息结束
      m.setQuestionBank(buildBank(5, prefix: 'big'));
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.quiz);
      expect(m.state.quiz!.questions.length, 5);
    });
  });

  group('跨天归零', () {
    test('跨过自然日，当日用量与阈值进度归零', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 20));
      expect(m.state.usedToday, const Duration(minutes: 20));

      clock = DateTime(2026, 10, 8, 0, 0, 1);
      m.tick();
      expect(m.state.usedToday, Duration.zero);
      expect(m.state.sinceLastGrant, Duration.zero);
      expect(m.state.phase, AppPhase.tracking);

      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.quiz);
    });
  });

  group('配置更新', () {
    test('缩短阈值且既有进度已达标时立即触发答题', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.tracking);
      m.updateSettings(
        AppSettings.defaults.copyWith(quizInterval: const Duration(minutes: 10)),
      );
      expect(m.state.phase, AppPhase.quiz);
    });

    test('提高阈值后既有进度不再触发答题', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 10));
      m.updateSettings(
        AppSettings.defaults.copyWith(quizInterval: const Duration(hours: 1)),
      );
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.quizInterval, const Duration(hours: 1));
    });
  });
}
