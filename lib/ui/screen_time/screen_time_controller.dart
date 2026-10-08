/// 屏幕时间 UI 控制器。
///
/// 桥接纯逻辑层的 [ScreenTimeMachine] 与 [QuestionBankService]：
/// - 状态机负责阶段流转（tracking/quiz/resting）与亮屏计时；
/// - 题库服务负责输入式题目的抽取与答错加权；
/// - 本控制器用 [Timer] 每秒驱动一次 [ScreenTimeMachine.tick]，
///   并在进入答题阶段时从题库服务抽取 [BankQuestion] 供答题页渲染。
///
/// UI 层只依赖本控制器，不直接接触状态机的内部 [Question] 模型。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/question_bank_service.dart';
import '../../state_machine/app_phase.dart';
import '../../state_machine/screen_time_machine.dart';
import '../locale_controller.dart';

/// 桥接状态机与题库服务的 UI 控制器。
class ScreenTimeController extends ChangeNotifier {
  /// 核心状态机。
  final ScreenTimeMachine machine;

  /// 题库服务（提供输入式题目）。
  final QuestionBankService bankService;

  /// 每轮答题抽取的题目数量。
  final int questionsPerQuiz;

  /// 语言控制器。
  final LocaleController localeController = LocaleController();

  Timer? _timer;

  /// 当前轮次抽到的输入式题目（仅在 quiz 阶段非空）。
  List<BankQuestion> quizQuestions = const [];

  /// 答题页当前展示的题目下标（一题一题作答）。
  int quizIndex = 0;

  /// 是否已展示过提醒页（进入 quiz 阶段先显示提醒，再进入答题）。
  bool reminderShown = false;

  /// 累计成功豁免的次数（答对达标回 tracking 时递增）。
  int exemptionCount = 0;

  ScreenTimeController({
    required this.machine,
    required this.bankService,
    this.questionsPerQuiz = 2,
    bool autoStart = true,
  }) {
    machine.addListener(_onMachinePhaseChange);
    // 假数据驱动：默认屏幕点亮，真实平台由原生层上报亮灭屏。
    machine.setScreenOn(true);
    if (autoStart) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => machine.tick());
    }
  }

  AppPhase get phase => machine.state.phase;

  /// 状态机阶段变化时的回调：进入 quiz 时抽题，离开时重置答题 UI 状态。
  void _onMachinePhaseChange() {
    final phase = machine.state.phase;
    if (phase == AppPhase.quiz) {
      if (quizQuestions.isEmpty) {
        _drawQuizQuestions();
        quizIndex = 0;
        reminderShown = false;
      }
    } else if (phase == AppPhase.tracking) {
      // 从 quiz 回到 tracking 且非首次进入：说明豁免成功。
      if (quizQuestions.isNotEmpty) {
        exemptionCount++;
      }
      quizQuestions = const [];
      quizIndex = 0;
      reminderShown = false;
    } else {
      // resting：重置答题状态。
      quizQuestions = const [];
      quizIndex = 0;
      reminderShown = false;
    }
    notifyListeners();
  }

  /// 从启用分组中抽取 [questionsPerQuiz] 道输入式题目。
  void _drawQuizQuestions() {
    try {
      quizQuestions = bankService.drawQuestions(questionsPerQuiz);
    } catch (_) {
      // 题量不足时回退为空，答题页将提示无法答题。
      quizQuestions = const [];
    }
  }

  /// 提醒页点击"继续使用"：首次豁免免费，其余进入答题。
  void continueUsage() {
    if (machine.state.quizRound <= 1) {
      // 首次豁免：直接判定通过（不答题）。
      _passAllQuestions();
    } else {
      reminderShown = true;
      notifyListeners();
    }
  }

  /// 提醒页/答题页点击"立即休息"：放弃本轮答题进入休息。
  void giveUp() {
    if (phase == AppPhase.quiz) {
      machine.giveUpQuiz();
    }
  }

  /// 主计时页"手动触发休息"。
  void manualRest() {
    if (phase == AppPhase.tracking) {
      machine.restNow();
    }
  }

  /// 对当前题目提交答案。
  ///
  /// 用 [BankQuestion.matchesAnswer] 判断对错，记录到题库服务以调整权重，
  /// 再将对错映射为状态机的选项下标推进答题会话。
  void submitAnswer(String input) {
    if (phase != AppPhase.quiz || quizQuestions.isEmpty) return;
    if (quizIndex >= quizQuestions.length) return;

    final question = quizQuestions[quizIndex];
    final correct = question.matchesAnswer(input);
    bankService.recordAnswer(question.id, correct: correct);

    final session = machine.state.quiz;
    if (session == null) return;
    final current = session.currentQuestion;
    if (current == null) return;

    // 答对选正确下标，答错选第一个干扰项。
    final optionIndex =
        correct ? current.correctIndex : (current.correctIndex == 0 ? 1 : 0);
    machine.answerCurrentQuestion(optionIndex);

    // 状态机通知会触发 _onMachinePhaseChange；若仍在 quiz，推进到下一题。
    if (machine.state.phase == AppPhase.quiz) {
      quizIndex++;
      notifyListeners();
    }
  }

  /// 模拟全部答对（用于首次免费豁免）。
  void _passAllQuestions() {
    final session = machine.state.quiz;
    if (session == null) return;
    while (!session.isComplete) {
      final current = session.currentQuestion;
      if (current == null) break;
      machine.answerCurrentQuestion(current.correctIndex);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    machine.removeListener(_onMachinePhaseChange);
    super.dispose();
  }
}
