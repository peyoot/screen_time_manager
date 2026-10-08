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

  /// 今日剩余可用豁免次数（状态机统一计数，跨天自动重置）。
  int get remainingExemptions => machine.remainingExemptions;

  /// 当前是否还能申请豁免。
  bool get canExempt => machine.canExempt;

  /// 休息期豁免：当前抽取的题目（休息阶段申请豁免后非空）。
  BankQuestion? restQuizQuestion;

  /// 休息期豁免：上次作答是否答错（答错后展示正确答案并允许重试）。
  bool restQuizFailed = false;

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
      // 回到计时阶段：重置所有答题 UI 状态（豁免计数由状态机维护）。
      quizQuestions = const [];
      quizIndex = 0;
      reminderShown = false;
      restQuizQuestion = null;
      restQuizFailed = false;
    } else {
      // resting：重置答题与休息期豁免状态。
      quizQuestions = const [];
      quizIndex = 0;
      reminderShown = false;
      restQuizQuestion = null;
      restQuizFailed = false;
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

  /// 提醒页点击"继续使用"：进入答题（能否豁免由剩余额度决定，
  /// 额度用完时状态机不会进入 quiz 阶段，提醒页不会出现）。
  void continueUsage() {
    reminderShown = true;
    notifyListeners();
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

  /// 休息页"申请豁免"：随机抽取一道题供用户作答。
  /// 今日豁免次数用完时不做任何操作（UI 已隐藏入口）。
  void requestRestExemption() {
    if (machine.state.phase != AppPhase.resting || !machine.canExempt) return;
    try {
      restQuizQuestion = bankService.drawQuestions(1).first;
    } catch (_) {
      // 题库题量不足时保持无题状态，页面停留在入口按钮。
      restQuizQuestion = null;
    }
    restQuizFailed = false;
    notifyListeners();
  }

  /// 提交休息期豁免答案。
  ///
  /// 答对返回 true 并由状态机消耗一次豁免额度、提前结束休息；
  /// 答错返回 false，此时 [restQuizFailed] 置真，
  /// UI 展示正确答案并允许重新抽题作答（答错不消耗额度）。
  bool submitRestAnswer(String input) {
    final question = restQuizQuestion;
    if (machine.state.phase != AppPhase.resting ||
        question == null ||
        !machine.canExempt) {
      return false;
    }
    final correct = question.matchesAnswer(input);
    bankService.recordAnswer(question.id, correct: correct);
    if (correct) {
      restQuizQuestion = null;
      restQuizFailed = false;
      machine.endRestEarly(); // 消耗额度并触发阶段变化，页面自动切回计时。
      return true;
    }
    restQuizFailed = true;
    notifyListeners();
    return false;
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

  @override
  void dispose() {
    _timer?.cancel();
    machine.removeListener(_onMachinePhaseChange);
    super.dispose();
  }
}
