import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/state_machine/app_phase.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';

void main() {
  // 状态机当前到点直接进休息，不再抽题；题库仅作为构造参数保留。
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

  /// 测试专用固定配置（与 AppSettings.defaults 解耦，默认值调整不影响本文件）。
  final testSettings = AppSettings(
    quizInterval: const Duration(minutes: 30),
    questionsPerQuiz: 1,
    requiredCorrectCount: 1,
    restDuration: const Duration(minutes: 3),
    dailyExemptionLimit: 2,
  );

  ScreenTimeMachine buildMachine({
    AppSettings? settings,
    QuestionBank? bank,
    bool initiallyScreenOn = true,
  }) {
    final machine = ScreenTimeMachine(
      settings: settings ?? testSettings,
      questionBank: bank ?? buildBank(10),
      clock: () => clock,
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
      expect(m.state.remainingToQuiz, testSettings.quizInterval);
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

  group('触发强制休息', () {
    test('累计达到阈值直接进入休息阶段（无答题中间态）', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 29, seconds: 59));
      expect(m.state.phase, AppPhase.tracking);

      advance(m, const Duration(seconds: 2));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.quiz, isNull);
      expect(m.state.restEndsAt, clock.add(const Duration(minutes: 3)));
    });

    test('阈值刚好达到时触发', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
    });

    test('休息阶段 tick 不累计亮屏时长', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      final before = m.state.usedToday;

      // 休息 3 分钟内推进 2 分钟：仍在休息，用量不变。
      advance(m, const Duration(minutes: 2));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.usedToday, before);
    });
  });

  group('强制休息开关（restEnabled）', () {
    final disabledSettings = AppSettings(
      quizInterval: const Duration(minutes: 30),
      questionsPerQuiz: 1,
      requiredCorrectCount: 1,
      restDuration: const Duration(minutes: 3),
      dailyExemptionLimit: 2,
      restEnabled: false,
    );

    test('关闭时达到阈值不进入休息，亮屏时长照常累计、阈值进度冻结', () {
      final m = buildMachine(settings: disabledSettings);
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.usedToday, const Duration(minutes: 30));
      expect(m.state.sinceLastGrant, Duration.zero);

      // 继续推进：依旧不触发休息，亮屏继续累计。
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.usedToday, const Duration(minutes: 40));
      expect(m.state.sinceLastGrant, Duration.zero);
    });

    test('关闭时手动触发休息抛出 StateError', () {
      final m = buildMachine(settings: disabledSettings);
      expect(m.restNow, throwsStateError);
      expect(m.state.phase, AppPhase.tracking);
    });

    test('关闭状态下缩短阈值低于既有进度也不会触发休息', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 20));
      m.updateSettings(disabledSettings.copyWith(
        quizInterval: const Duration(minutes: 10),
      ));
      expect(m.state.phase, AppPhase.tracking);
    });

    test('重新启用后阈值进度从冻结值继续累计并可触发休息', () {
      final m = buildMachine();
      // 先累计 20 分钟进度，然后关闭开关再推进 15 分钟（进度冻结）。
      advance(m, const Duration(minutes: 20));
      m.updateSettings(disabledSettings);
      advance(m, const Duration(minutes: 15));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.sinceLastGrant, const Duration(minutes: 20));

      // 重新启用：再累计 10 分钟达到 30 分钟阈值 → 进入休息。
      m.updateSettings(testSettings);
      expect(m.state.phase, AppPhase.tracking);
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.resting);
    });
  });

  group('休息结束与豁免流转', () {
    test('到点进休息，休息自然结束回到计时并重新累计阈值', () {
      final settings = AppSettings(
        quizInterval: const Duration(minutes: 5),
        questionsPerQuiz: 2,
        requiredCorrectCount: 2,
        restDuration: const Duration(minutes: 3),
      );
      final m = buildMachine(settings: settings);
      advance(m, const Duration(minutes: 5));
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

      // 新一轮累计到阈值再次直接进入休息。
      advance(m, const Duration(minutes: 5));
      expect(m.state.phase, AppPhase.resting);
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
      expect(m.state.phase, AppPhase.resting);

      // 一次性跳过 8 分钟：3 分钟休息 + 5 分钟新一轮亮屏，
      // 应在同一个 tick 内再次触发休息。
      advance(m, const Duration(minutes: 8));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.usedToday, const Duration(minutes: 10));
    });

    test('手动触发休息（restNow）并自然结束', () {
      final m = buildMachine();
      m.restNow();
      expect(m.state.phase, AppPhase.resting);
      expect(
        m.state.restEndsAt,
        clock.add(const Duration(minutes: 3)),
      );

      advance(m, const Duration(minutes: 3));
      expect(m.state.phase, AppPhase.tracking);
    });

    test('非计时阶段手动触发休息抛出 StateError', () {
      final m = buildMachine();
      m.restNow();
      expect(m.restNow, throwsStateError);
    });

    test('quiz 阶段不可达：作答/放弃均抛出 StateError', () {
      final m = buildMachine();
      expect(() => m.answerCurrentQuestion(1), throwsStateError);
      expect(m.giveUpQuiz, throwsStateError);

      // 到点进休息后同样不是答题阶段。
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
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
        settings: testSettings,
        questionBank: null,
        clock: () => clock,
        initiallyScreenOn: true,
      );
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.quiz, isNull);
    });

    test('到点休息与题库无关：更换题库后下一轮仍直接进休息', () {
      final m = buildMachine(bank: buildBank(2));
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);

      advance(m, const Duration(minutes: 3)); // 休息结束
      expect(m.state.phase, AppPhase.tracking);

      m.setQuestionBank(buildBank(5, prefix: 'big'));
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
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
      expect(m.state.phase, AppPhase.resting);
    });
  });

  group('配置更新', () {
    test('缩短阈值且既有进度已达标时立即触发休息', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 10));
      expect(m.state.phase, AppPhase.tracking);
      m.updateSettings(
        AppSettings.defaults.copyWith(quizInterval: const Duration(minutes: 10)),
      );
      expect(m.state.phase, AppPhase.resting);
    });

    test('提高阈值后既有进度不再触发休息', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 10));
      m.updateSettings(
        AppSettings.defaults.copyWith(quizInterval: const Duration(hours: 1)),
      );
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.quizInterval, const Duration(hours: 1));
    });
  });

  group('每日豁免次数限制', () {
    /// 连续 [rounds] 轮：到阈值进休息 → 休息页答题豁免通过（endRestEarly），
    /// 每轮消耗一次今日豁免额度（默认配置每轮 30 分钟阈值）。
    void passRounds(ScreenTimeMachine m, int rounds) {
      for (var i = 0; i < rounds; i++) {
        advance(m, const Duration(minutes: 30));
        expect(m.state.phase, AppPhase.resting, reason: '第 ${i + 1} 轮应进入休息');
        m.endRestEarly();
        expect(m.state.phase, AppPhase.tracking);
      }
    }

    test('默认每日 2 次：豁免两轮各消耗一次，剩余 0', () {
      final m = buildMachine();
      expect(m.remainingExemptions, 2);
      expect(m.canExempt, isTrue);

      passRounds(m, 2);
      expect(m.state.exemptionsUsedToday, 2);
      expect(m.remainingExemptions, 0);
      expect(m.canExempt, isFalse);
    });

    test('次数用完后再次达到阈值直接进入强制休息', () {
      final m = buildMachine();
      passRounds(m, 2);

      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.quiz, isNull);
    });

    test('次数用完后 endRestEarly 抛出 StateError', () {
      final m = buildMachine();
      passRounds(m, 2);
      advance(m, const Duration(minutes: 30)); // 直接进入休息
      expect(m.state.phase, AppPhase.resting);
      expect(m.endRestEarly, throwsStateError);
      expect(m.state.phase, AppPhase.resting);
    });

    test('额度为 0 时第一次达到阈值就直接休息', () {
      final settings = testSettings.copyWith(dailyExemptionLimit: 0);
      final m = buildMachine(settings: settings);
      expect(m.canExempt, isFalse);
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.exemptionsUsedToday, 0);
    });

    test('额度用尽后完成完整休息，豁免次数重新充满', () {
      final m = buildMachine();
      passRounds(m, 2);
      advance(m, const Duration(minutes: 30)); // 第三次直接强制休息
      expect(m.state.phase, AppPhase.resting);
      expect(m.remainingExemptions, 0);

      // 完整休息 3 分钟结束（非答题提前结束）→ 次数重置为 2。
      advance(m, const Duration(minutes: 3));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.remainingExemptions, 2);
      expect(m.state.exemptionsUsedToday, 0);

      // 重置后可再次豁免。
      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      m.endRestEarly();
      expect(m.state.phase, AppPhase.tracking);
      expect(m.remainingExemptions, 1);
    });

    test('仍有额度时完成普通休息不重置已用次数', () {
      final m = buildMachine();
      passRounds(m, 1); // 已用 1 次，剩余 1
      expect(m.remainingExemptions, 1);

      m.restNow(); // 手动休息，完整结束
      advance(m, const Duration(minutes: 3));
      expect(m.state.phase, AppPhase.tracking);
      expect(m.remainingExemptions, 1); // 不重置
    });

    test('豁免提前结束休息不触发次数重置', () {
      final m = buildMachine();
      passRounds(m, 1); // 剩余 1
      m.restNow();
      m.endRestEarly(); // 用掉最后一次额度提前结束
      expect(m.state.phase, AppPhase.tracking);
      expect(m.remainingExemptions, 0);
    });

    test('跨自然日后豁免次数归零，可再次豁免', () {
      final m = buildMachine();
      passRounds(m, 2);
      advance(m, const Duration(minutes: 30)); // 第三次直接休息
      expect(m.state.phase, AppPhase.resting);

      // 跨入第二天，休息已结束，计数归零。
      clock = DateTime(2026, 10, 8, 0, 4, 0);
      m.tick();
      expect(m.state.exemptionsUsedToday, 0);
      expect(m.remainingExemptions, 2);

      advance(m, const Duration(minutes: 30));
      expect(m.state.phase, AppPhase.resting);
      m.endRestEarly();
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.exemptionsUsedToday, 1);
    });
  });

  group('当日快照恢复 restoreDay', () {
    test('恢复累计亮屏、阈值进度与已用豁免', () {
      final m = buildMachine();
      m.restoreDay(
        usedToday: const Duration(minutes: 20),
        thresholdProgress: const Duration(minutes: 10),
        exemptionsUsedToday: 1,
      );
      expect(m.state.usedToday, const Duration(minutes: 20));
      expect(m.state.sinceLastGrant, const Duration(minutes: 10));
      expect(m.state.exemptionsUsedToday, 1);
      expect(m.remainingExemptions, 1);
      expect(m.state.remainingToQuiz, const Duration(minutes: 20));
      expect(m.state.phase, AppPhase.tracking);
    });

    test('恢复后继续累计并按既有进度到点进休息', () {
      final m = buildMachine();
      m.restoreDay(
        usedToday: const Duration(minutes: 25),
        thresholdProgress: const Duration(minutes: 29),
      );
      advance(m, const Duration(minutes: 1));
      expect(m.state.phase, AppPhase.resting);
      // 到点触发后阈值进度清零；触发前这一分钟仍计入当日累计。
      expect(m.state.usedToday, const Duration(minutes: 26));
    });

    test('未过期的休息截止时刻恢复为休息中', () {
      final m = buildMachine();
      m.restoreDay(
        usedToday: const Duration(minutes: 30),
        thresholdProgress: Duration.zero,
        restEndsAt: clock.add(const Duration(minutes: 2)),
      );
      expect(m.state.phase, AppPhase.resting);
      expect(m.state.restEndsAt, clock.add(const Duration(minutes: 2)));
      // 休息期不累计亮屏。
      advance(m, const Duration(minutes: 1));
      expect(m.state.usedToday, const Duration(minutes: 30));
      // 休息自然结束后回到计时。
      advance(m, const Duration(minutes: 2));
      expect(m.state.phase, AppPhase.tracking);
    });

    test('已过期的休息截止时刻被忽略，按计时阶段继续', () {
      final m = buildMachine();
      m.restoreDay(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 5),
        restEndsAt: clock.subtract(const Duration(minutes: 1)),
      );
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.restEndsAt, isNull);
      expect(m.state.usedToday, const Duration(minutes: 5));
    });
  });

  group('远离手机（away）统计（本地模式）', () {
    test('休息自然结束时屏幕亮 → 计入 [restStart, now]', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30)); // 达阈值进休息
      expect(m.state.phase, AppPhase.resting);
      advance(m, const Duration(minutes: 3)); // 休息自然结束（屏幕亮）
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.awayClosed, const Duration(minutes: 3));
      expect(m.state.pendingAwayStart, isNull);
    });

    test('休息结束时屏幕灭 → 挂起，下次亮屏计入全程', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30)); // 达阈值进休息
      m.setScreenOn(false);
      advance(m, const Duration(minutes: 3)); // 灭屏中休息结束 → 挂起
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.awayClosed, Duration.zero);
      expect(m.state.pendingAwayStart, isNotNull);
      // 灭屏 10 分钟后重新亮屏：计入 [restStart, 亮屏] 全程（3+10 分钟）。
      advance(m, const Duration(minutes: 10));
      expect(m.state.awayClosed, Duration.zero);
      m.setScreenOn(true);
      expect(m.state.awayClosed, const Duration(minutes: 13));
      expect(m.state.pendingAwayStart, isNull);
    });

    test('休息期豁免通过（屏幕亮）→ 计入实际休息时长', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      advance(m, const Duration(minutes: 1)); // 休息进行 1 分钟
      m.endRestEarly();
      expect(m.state.phase, AppPhase.tracking);
      expect(m.state.awayClosed, const Duration(minutes: 1));
    });

    test('跨自然日归零并丢弃挂起片段', () {
      final m = buildMachine();
      advance(m, const Duration(minutes: 30));
      m.setScreenOn(false);
      advance(m, const Duration(minutes: 3)); // 灭屏结束 → 挂起片段
      expect(m.state.pendingAwayStart, isNotNull);
      advance(m, const Duration(hours: 16)); // 跨到第二天
      expect(m.state.awayClosed, Duration.zero);
      expect(m.state.pendingAwayStart, isNull);
      // 次日亮屏不再补记昨日挂起片段。
      m.setScreenOn(true);
      expect(m.state.awayClosed, Duration.zero);
    });
  });
}
