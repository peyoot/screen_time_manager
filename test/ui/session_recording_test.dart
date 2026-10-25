import 'package:flutter_test/flutter_test.dart';
import 'package:screen_tempo/data/repositories/question_repository.dart';
import 'package:screen_tempo/data/repositories/rest_session_repository.dart';
import 'package:screen_tempo/data/repositories/screen_session_repository.dart';
import 'package:screen_tempo/data/repositories/snooze_record_repository.dart';
import 'package:screen_tempo/models/app_settings.dart';
import 'package:screen_tempo/question_bank/bank_question.dart';
import 'package:screen_tempo/question_bank/question_bank_service.dart';
import 'package:screen_tempo/state_machine/screen_time_machine.dart';
import 'package:screen_tempo/ui/screen_time/screen_time_controller.dart';

import '../data/_helpers.dart';

void main() {
  late DateTime now;
  late ScreenTimeController controller;
  late ScreenTimeMachine machine;
  late RestSessionRepository restRepo;
  late SnoozeRecordRepository snoozeRepo;

  setUp(() async {
    now = DateTime(2026, 10, 9, 8, 0);
    final db = await openTestDb();
    restRepo = RestSessionRepository(db);
    snoozeRepo = SnoozeRecordRepository(db);
    final questionRepo = QuestionRepository(db);

    final bankService = QuestionBankService(repository: questionRepo);
    bankService.importIntoNewGroup(
      name: '组',
      questions: [
        BankQuestion(id: 'bq0', question: '一加一', answer: '2'),
        BankQuestion(id: 'bq1', question: '二加二', answer: '4'),
        BankQuestion(id: 'bq2', question: '三加三', answer: '6'),
        BankQuestion(id: 'bq3', question: '四加四', answer: '8'),
      ],
    );
    await bankService.flush();

    machine = ScreenTimeMachine(
      settings: AppSettings.defaults.copyWith(
        questionsPerQuiz: 2,
        requiredCorrectCount: 1,
        quizInterval: const Duration(minutes: 15),
        restDuration: const Duration(minutes: 1),
      ),
      clock: () => now,
      initiallyScreenOn: true,
    );

    controller = ScreenTimeController(
      machine: machine,
      bankService: bankService,
      questionsPerQuiz: 2,
      screenSessionRepo: ScreenSessionRepository(db),
      restSessionRepo: restRepo,
      snoozeRecordRepo: snoozeRepo,
      clock: () => now,
      autoStart: false,
    );
  });

  /// 推进虚拟时钟并触发一次 tick。
  void advance(Duration d) {
    now = now.add(d);
    machine.tick();
  }

  test('到点进休息后答题豁免通过 → 写入 passed=true 的 snooze_record', () async {
    advance(const Duration(minutes: 16)); // 阈值 15 分钟 → 直接进休息
    expect(machine.state.phase.name, 'resting');
    controller.requestRestExemption();
    expect(controller.restQuizQuestion, isNotNull);
    // 抽题非确定，按实际抽中的题目答案作答。
    final correct =
        controller.submitRestAnswer(controller.restQuizQuestion!.answer);
    expect(correct, isTrue);
    expect(machine.state.phase.name, 'tracking');
    await Future<void>.delayed(Duration.zero);
    final snoozes = await snoozeRepo.listRecent();
    expect(snoozes.length, 1);
    expect(snoozes.first.passed, true);
    expect(snoozes.first.correctCount, 1);
    expect(machine.remainingExemptions, 1); // 默认 2，用掉 1
  });

  test('自然结束休息 → rest_session completed=true', () async {
    controller.manualRest();
    expect(machine.state.phase.name, 'resting');
    advance(const Duration(minutes: 2)); // 超过 1 分钟计划
    expect(machine.state.phase.name, 'tracking');
    await Future<void>.delayed(Duration.zero);
    final rests = await restRepo.listRecent();
    expect(rests.length, 1);
    expect(rests.first.completed, true);
    expect(rests.first.plannedDuration, const Duration(minutes: 1));
  });

  test('豁免提前结束休息 → rest_session completed=false', () async {
    controller.manualRest();
    expect(machine.state.phase.name, 'resting');
    controller.requestRestExemption();
    expect(controller.restQuizQuestion, isNotNull);
    final correct = controller.submitRestAnswer(controller.restQuizQuestion!.answer);
    expect(correct, isTrue);
    expect(machine.state.phase.name, 'tracking');
    await Future<void>.delayed(Duration.zero);
    final rests = await restRepo.listRecent();
    expect(rests.length, 1);
    expect(rests.first.completed, false);
  });

  test('休息期豁免答错 → snooze_record passed=false', () async {
    controller.manualRest();
    controller.requestRestExemption();
    final correct = controller.submitRestAnswer('错误答案');
    expect(correct, isFalse);
    await Future<void>.delayed(Duration.zero);
    final snoozes = await snoozeRepo.listRecent();
    expect(snoozes.length, 1);
    expect(snoozes.first.passed, false);
    expect(snoozes.first.wrongCount, 1);
  });

  test('当日休息统计：触发次数与累计时长随休息进度更新', () async {
    expect(controller.todayRestCount, 0);
    expect(controller.todayRestDuration, Duration.zero);

    // 第一次休息（豁免提前结束，实际 30 秒）。
    controller.manualRest();
    expect(controller.todayRestCount, 1);
    expect(controller.todayRestDuration, Duration.zero);
    advance(const Duration(seconds: 30));
    // 休息进行中：累计时长实时计入。
    expect(controller.todayRestDuration, const Duration(seconds: 30));
    controller.requestRestExemption();
    controller.submitRestAnswer(controller.restQuizQuestion!.answer);
    expect(machine.state.phase.name, 'tracking');
    expect(controller.todayRestCount, 1);
    expect(controller.todayRestDuration, const Duration(seconds: 30));
    // 豁免通过一次：今日豁免计数 +1。
    expect(controller.todayRestExemptions, 1);

    // 第二次休息（再进行 10 秒）：次数 +1，时长累加。
    controller.manualRest();
    expect(controller.todayRestCount, 2);
    advance(const Duration(seconds: 10));
    expect(controller.todayRestDuration, const Duration(seconds: 40));
  });

  test('当日休息统计：跨自然日归零并重新计数', () async {
    controller.manualRest();
    expect(controller.todayRestCount, 1);
    advance(const Duration(minutes: 2)); // 自然结束第一次休息
    expect(machine.state.phase.name, 'tracking');

    // 直接跳到次日早晨并手动触发休息：
    // 进入 resting 前控制器应检测跨天并归零，本次记为新一天第 1 次。
    now = DateTime(2026, 10, 10, 9, 0);
    controller.manualRest();
    expect(machine.state.phase.name, 'resting');
    expect(controller.todayRestCount, 1);
    expect(controller.todayRestDuration, Duration.zero);
    expect(controller.todayRestExemptions, 0);

    // 次日这次休息自然结束：只累计新一天内的时长（2 分钟）。
    advance(const Duration(minutes: 2));
    expect(machine.state.phase.name, 'tracking');
    expect(controller.todayRestCount, 1);
    expect(controller.todayRestDuration, const Duration(minutes: 2));
  });
}
