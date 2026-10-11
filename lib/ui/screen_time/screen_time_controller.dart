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
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/rest_session_repository.dart';
import '../../data/repositories/screen_session_repository.dart';
import '../../data/repositories/snooze_record_repository.dart';
import '../../models/rest_session.dart';
import '../../models/screen_session.dart';
import '../../models/snooze_record.dart';
import '../../platform_channel/platform_channels.dart';
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

  // 可选的持久化后端；为 null 时跳过对应写入（测试/无 DB 阶段）。
  final AppSettingsRepository? appSettingsRepo;
  final ScreenSessionRepository? screenSessionRepo;
  final RestSessionRepository? restSessionRepo;
  final SnoozeRecordRepository? snoozeRecordRepo;

  /// 可选的到点干预桥：阶段变为 quiz/resting 时通知原生把界面拉到前台。
  /// 为 null（桌面/Web/测试）时不产生任何平台调用。
  final InterventionBridge? interventionBridge;

  /// 平台亮灭屏事件订阅（Android 前台服务经 EventChannel 推送）。
  StreamSubscription<bool>? _screenEventsSub;

  final Uuid _uuid = const Uuid();
  final DateTime Function() _clock;

  // 会话记录的运行时跟踪状态（内存，结束时刻落库）。
  DateTime? _screenSessionStart;
  String? _currentScreenSessionId;
  int _screenExemptions = 0;
  int _screenQuizCorrect = 0;
  int _screenQuizWrong = 0;
  DateTime? _restStart;
  Duration? _restPlanned;
  bool _restEndedEarly = false;
  AppPhase _lastPhase = AppPhase.tracking;

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
    this.appSettingsRepo,
    this.screenSessionRepo,
    this.restSessionRepo,
    this.snoozeRecordRepo,
    this.interventionBridge,
    Stream<bool>? screenOnEvents,
    DateTime Function()? clock,
    bool autoStart = true,
  }) : _clock = clock ?? DateTime.now {
    machine.addListener(_onMachinePhaseChange);
    // 屏幕会话起点：真实平台由原生层上报亮灭屏时再切分。
    _screenSessionStart = _clock();
    _currentScreenSessionId = _uuid.v4();
    _lastPhase = machine.state.phase;
    machine.setScreenOn(true);
    // Android：订阅原生亮灭屏事件；灭屏期间状态机不累计亮屏时长。
    _screenEventsSub =
        screenOnEvents?.listen((isOn) => reportScreenOn(isOn));
    if (autoStart) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => machine.tick());
    }
  }

  AppPhase get phase => machine.state.phase;

  /// 状态机阶段变化时的回调：进入 quiz 时抽题，离开时重置答题 UI 状态。
  /// 同时记录休息会话（rest_session）的起止。
  void _onMachinePhaseChange() {
    final phase = machine.state.phase;
    final previousPhase = _lastPhase;
    // 离开 resting 阶段：落库一条休息会话。
    if (previousPhase == AppPhase.resting && phase != AppPhase.resting) {
      _flushRestSession(naturalCompletion: !_restEndedEarly);
      _restEndedEarly = false;
    }
    // 进入 resting 阶段：记录起点与计划时长。
    if (phase == AppPhase.resting && previousPhase != AppPhase.resting) {
      _restStart = _clock();
      _restPlanned = machine.settings.restDuration;
    }
    _lastPhase = phase;

    // 到点干预：进入答题/休息时请求原生把界面拉到前台；
    // 从这两个阶段回到计时时撤销干预。原生侧自行判断 App 是否已在前台。
    final bridge = interventionBridge;
    if (bridge != null) {
      if (phase == AppPhase.quiz && previousPhase != AppPhase.quiz) {
        unawaited(bridge.request(InterventionPhase.quiz));
      } else if (phase == AppPhase.resting &&
          previousPhase != AppPhase.resting) {
        unawaited(bridge.request(InterventionPhase.resting));
      } else if (phase == AppPhase.tracking &&
          (previousPhase == AppPhase.quiz ||
              previousPhase == AppPhase.resting)) {
        unawaited(bridge.dismiss());
      }
    }

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

  /// 把已结束的休息会话写入 DB（仅 [restSessionRepo] 存在时）。
  void _flushRestSession({required bool naturalCompletion}) {
    final start = _restStart;
    final planned = _restPlanned;
    final repo = restSessionRepo;
    if (start == null || planned == null || repo == null) {
      _restStart = null;
      _restPlanned = null;
      return;
    }
    final end = _clock();
    final actual = end.difference(start);
    final session = RestSession(
      id: _uuid.v4(),
      startedAt: start,
      endedAt: end,
      plannedDuration: planned,
      actualDuration: actual,
      completed: naturalCompletion,
    );
    _restStart = null;
    _restPlanned = null;
    repo.insert(session).catchError((_) {});
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

  /// 更新计时配置：亮屏触发时长与强制休息时长（单位：分钟）。
  ///
  /// 非法取值（<= 0）抛出 [ArgumentError]（由 [AppSettings] 构造函数校验）。
  /// 若缩短亮屏时长且既有进度已达到新阈值，状态机会立即触发答题/休息。
  void updateTiming({required int quizMinutes, required int restMinutes}) {
    machine.updateSettings(
      machine.settings.copyWith(
        quizInterval: Duration(minutes: quizMinutes),
        restDuration: Duration(minutes: restMinutes),
      ),
    );
    appSettingsRepo?.upsert(machine.settings).catchError((_) {});
  }

  /// 平台层上报亮灭屏。结束当前亮屏会话并落库（灭屏时），
  /// 亮屏时开启新会话。无 [screenSessionRepo] 时仅转发给状态机。
  void reportScreenOn(bool isOn) {
    if (isOn) {
      machine.setScreenOn(true);
      _screenSessionStart = _clock();
      _currentScreenSessionId = _uuid.v4();
      _screenExemptions = 0;
      _screenQuizCorrect = 0;
      _screenQuizWrong = 0;
    } else {
      _flushScreenSession();
      machine.setScreenOn(false);
    }
  }

  /// 把当前亮屏会话写入 DB（灭屏或应用退出时）。
  void _flushScreenSession() {
    final start = _screenSessionStart;
    final repo = screenSessionRepo;
    if (start == null || repo == null) {
      _screenSessionStart = null;
      return;
    }
    final end = _clock();
    final session = ScreenSession(
      id: _uuid.v4(),
      startedAt: start,
      endedAt: end,
      exemptionCount: _screenExemptions,
      quizCorrectCount: _screenQuizCorrect,
      quizWrongCount: _screenQuizWrong,
    );
    _screenSessionStart = null;
    _currentScreenSessionId = null;
    repo.insert(session).catchError((_) {});
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
    final round = machine.state.quizRound;
    if (correct) {
      _recordSnooze(
        questionIds: [question.id],
        passed: true,
        correctCount: 1,
        wrongCount: 0,
        round: round,
      );
      restQuizQuestion = null;
      restQuizFailed = false;
      _restEndedEarly = true;
      machine.endRestEarly(); // 消耗额度并触发阶段变化，页面自动切回计时。
      return true;
    }
    _recordSnooze(
      questionIds: [question.id],
      passed: false,
      correctCount: 0,
      wrongCount: 1,
      round: round,
    );
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
    // 调用前快照：本轮抽到的题目 id 与已答对错统计，便于结束后落库。
    final drawnIds = quizQuestions.map((q) => q.id).toList();
    final round = machine.state.quizRound;
    final correctSoFar = session.correctCount + (correct ? 1 : 0);
    final wrongSoFar = session.answeredCount - session.correctCount +
        (correct ? 0 : 1);
    machine.answerCurrentQuestion(optionIndex);

    // 离开 quiz 阶段：本轮答题结束，写入豁免明细。
    if (machine.state.phase != AppPhase.quiz) {
      _recordSnooze(
        questionIds: drawnIds,
        passed: machine.state.phase == AppPhase.tracking,
        correctCount: correctSoFar,
        wrongCount: wrongSoFar,
        round: round,
      );
      if (machine.state.phase == AppPhase.tracking) {
        _screenExemptions++;
      }
      _screenQuizCorrect += correctSoFar;
      _screenQuizWrong += wrongSoFar;
    } else if (machine.state.phase == AppPhase.quiz) {
      quizIndex++;
      notifyListeners();
    }
  }

  /// 写入一条豁免明细（snooze_record）。仅 [snoozeRecordRepo] 存在时落库。
  void _recordSnooze({
    required List<String> questionIds,
    required bool passed,
    required int correctCount,
    required int wrongCount,
    required int round,
  }) {
    final repo = snoozeRecordRepo;
    if (repo == null) return;
    final record = SnoozeRecord(
      id: _uuid.v4(),
      screenSessionId: _currentScreenSessionId,
      quizRound: round,
      questionIdsJson: jsonEncode(questionIds),
      passed: passed,
      correctCount: correctCount,
      wrongCount: wrongCount,
    );
    repo.insert(record).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _screenEventsSub?.cancel();
    machine.removeListener(_onMachinePhaseChange);
    // 应用退出时落库当前亮屏会话（若仍进行中）。
    _flushScreenSession();
    super.dispose();
  }
}
