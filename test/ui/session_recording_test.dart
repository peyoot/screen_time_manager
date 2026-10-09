import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/data/repositories/question_repository.dart';
import 'package:screen_time_manager/data/repositories/rest_session_repository.dart';
import 'package:screen_time_manager/data/repositories/screen_session_repository.dart';
import 'package:screen_time_manager/data/repositories/snooze_record_repository.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';
import 'package:screen_time_manager/ui/screen_time/screen_time_controller.dart';

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

    final machineBank = QuestionBank(
      id: 'machine',
      name: '状态机题库',
      questions: List.generate(
        4,
        (i) => Question(
          id: 'mq$i',
          prompt: '占位 $i',
          options: const ['错', '对'],
          correctIndex: 1,
        ),
      ),
    );

    machine = ScreenTimeMachine(
      settings: AppSettings.defaults.copyWith(
        questionsPerQuiz: 2,
        requiredCorrectCount: 1,
        quizInterval: const Duration(minutes: 15),
        restDuration: const Duration(minutes: 1),
      ),
      questionBank: machineBank,
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

  test('答题通过 → 写入 passed=true 的 snooze_record', () async {
    advance(const Duration(minutes: 16));
    expect(machine.state.phase.name, 'quiz');
    controller.continueUsage();
    // 抽题非确定，按实际抽中的题目答案作答。
    controller.submitAnswer(controller.quizQuestions[0].answer);
    controller.submitAnswer(controller.quizQuestions[1].answer);
    expect(machine.state.phase.name, 'tracking');
    await Future<void>.delayed(Duration.zero);
    final snoozes = await snoozeRepo.listRecent();
    expect(snoozes.length, 1);
    expect(snoozes.first.passed, true);
    expect(snoozes.first.correctCount, 2);
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
}
