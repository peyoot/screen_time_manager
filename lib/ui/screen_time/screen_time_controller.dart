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
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:uuid/uuid.dart';

import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/day_snapshot_repository.dart';
import '../../data/repositories/rest_session_repository.dart';
import '../../data/repositories/screen_session_repository.dart';
import '../../data/repositories/snooze_record_repository.dart';
import '../../models/day_snapshot.dart';
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
  final DaySnapshotRepository? daySnapshotRepo;
  final ScreenSessionRepository? screenSessionRepo;
  final RestSessionRepository? restSessionRepo;
  final SnoozeRecordRepository? snoozeRecordRepo;

  /// 可选的到点干预桥：阶段变为 quiz/resting 时通知原生把界面拉到前台。
  /// 为 null（桌面/Web/测试）时不产生任何平台调用。
  final InterventionBridge? interventionBridge;

  /// 可选的监控/权限通道：权限引导页查询状态与跳转设置页使用。
  /// 为 null（桌面/Web/测试）时权限页显示不可用提示。
  final MonitorChannel? monitor;

  /// 平台亮灭屏事件订阅（Android 前台服务经 EventChannel 推送）。
  StreamSubscription<bool>? _screenEventsSub;

  /// 原生权威计时核心（Android）；null 时控制器走本地 Timer 驱动状态机。
  ///
  /// 非 null 时：每秒读取原生快照镜像展示、用户操作回写原生，并停止本地
  /// tick/统计/干预（原生 `ScreenTimeCore` 是唯一计时源）。
  final TimeCore? timeCore;

  /// 原生核心快照同步的重入保护（避免慢快照堆叠）。
  bool _syncing = false;

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

  // -- 当日休息统计（纯内存，不依赖 DB；跨自然日自动归零）--
  /// 统计所属自然日（零点），用于检测跨天重置。
  late DateTime _restStatsDay;

  /// 当日进入休息页的次数（含当前进行中的一次）。
  int _todayRestCount = 0;

  /// 当日已完成休息的实际时长累计；进行中的部分由 [todayRestDuration] 实时补上。
  Duration _todayRestElapsed = Duration.zero;

  /// 当日通过答题成功豁免休息的累计次数（跨自然日归零）。
  /// 注意不能用状态机的 exemptionsUsedToday：自然完成完整休息后它会重置。
  int _todayRestExemptions = 0;

  Timer? _timer;

  /// 当日快照写入节流间隔（约 5 秒一条；被杀最多丢 5 秒累计）。
  static const _snapshotInterval = Duration(seconds: 5);

  /// 上次当日快照写入时刻。
  DateTime _lastSnapshotAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    this.daySnapshotRepo,
    this.screenSessionRepo,
    this.restSessionRepo,
    this.snoozeRecordRepo,
    this.interventionBridge,
    this.monitor,
    this.timeCore,
    Stream<bool>? screenOnEvents,
    DateTime Function()? clock,
    bool autoStart = true,
  }) : _clock = clock ?? DateTime.now {
    _restStatsDay = _dayOf(_clock());
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
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  /// 从 [daySnapshotRepo] 恢复当日进度（进程被杀/划掉重启后调用）。
  ///
  /// 快照缺失或属于其他自然日时为 no-op。恢复内容：状态机当日累计
  /// 亮屏/阈值进度/已用豁免、当日休息统计；若重启前正处于休息期且
  /// 截止时刻未过，状态机恢复为休息中——钩子会照常发起全屏干预，
  /// 把用户拉回休息页（随后此处用快照值对齐计数，避免重复统计）。
  /// 应在挂 UI 前 await，避免首帧显示归零数据。
  Future<void> restoreFromSnapshot() async {
    final core = timeCore;
    if (core != null) {
      await _restoreFromCore(core);
      return;
    }
    final repo = daySnapshotRepo;
    if (repo == null) return;
    final now = _clock();
    final snapshot = await repo.loadForDay(now);
    if (snapshot == null || !snapshot.isForDay(now)) return;
    machine.restoreDay(
      usedToday: snapshot.screenTime,
      thresholdProgress: snapshot.thresholdProgress,
      exemptionsUsedToday: snapshot.exemptionsUsedToday,
      restEndsAt: snapshot.restEndsAt,
    );
    // restoreDay 的通知若触发了"进入休息"钩子，计数已被 +1；
    // 用快照值对齐（快照的 rest_count/rest_seconds 已含进行中的休息）。
    _todayRestCount = snapshot.restCount;
    _todayRestElapsed = snapshot.restElapsed;
    _todayRestExemptions = snapshot.restExemptions;
    _flushDaySnapshot(force: true);
    notifyListeners();
  }

  /// 原生权威模式下恢复当日状态：优先读原生快照；原生尚未有当日数据时
  /// 用本地 DB 快照 seed（升级迁移，避免首次切到原生模式时当日数据归零）。
  Future<void> _restoreFromCore(TimeCore core) async {
    try {
      var snap = await core.snapshot();
      if (!snap.hasDayData) {
        final repo = daySnapshotRepo;
        if (repo != null) {
          final now = _clock();
          final local = await repo.loadForDay(now);
          if (local != null && local.isForDay(now)) {
            await core.seedFromSnapshot(
              usedToday: local.screenTime,
              thresholdProgress: local.thresholdProgress,
              exemptionsUsedToday: local.exemptionsUsedToday,
              resting:
                  local.restEndsAt != null && local.restEndsAt!.isAfter(now),
              restEndsAt: local.restEndsAt,
            );
            snap = await core.snapshot();
          }
        }
      }
      _applySnapshot(snap);
    } catch (e) {
      debugPrint('原生计时核心快照恢复失败，跳过: $e');
    }
  }

  /// 把当日运行状态写入快照表（[force] 为 true 时跳过节流）。
  /// 快照只作健壮性优化，写失败静默，不阻塞主流程。
  void _flushDaySnapshot({bool force = false}) {
    // 原生权威模式下当日状态由原生核心持久化，Dart 侧无需再写快照。
    if (timeCore != null) return;
    final repo = daySnapshotRepo;
    if (repo == null) return;
    final now = _clock();
    if (!force && now.difference(_lastSnapshotAt) < _snapshotInterval) return;
    _lastSnapshotAt = now;
    final state = machine.state;
    repo
        .upsert(DaySnapshot(
          day: _dayOf(now),
          screenTime: state.usedToday,
          thresholdProgress: state.sinceLastGrant,
          exemptionsUsedToday: state.exemptionsUsedToday,
          restCount: _todayRestCount,
          restElapsed: todayRestDuration,
          restExemptions: _todayRestExemptions,
          restEndsAt: state.restEndsAt,
        ))
        .catchError((_) {});
  }

  /// 每秒 tick：原生模式读原生快照镜像；否则本地推进状态机。
  void _onTick() {
    final core = timeCore;
    if (core == null) {
      _rolloverRestStatsIfNeeded();
      machine.tick();
      _flushDaySnapshot();
      return;
    }
    if (_syncing) return;
    _syncing = true;
    unawaited(_syncFromCore(core));
  }

  /// 读取一次原生权威快照并镜像到状态机与当日休息统计。
  Future<void> _syncFromCore(TimeCore core) async {
    try {
      _applySnapshot(await core.snapshot());
    } catch (_) {
      // 通道异常：跳过本次同步，下一轮重试。
    } finally {
      _syncing = false;
    }
  }

  /// 把原生快照镜像到状态机（触发既有阶段钩子）并覆盖当日休息统计。
  ///
  /// 原生是当日休息统计的权威源，故直接覆盖而非累加；[snap] 的
  /// `restCompleted` 仅含已完成休息，进行中的部分由 [todayRestDuration]
  /// 用 `_restStart` 实时补上。
  void _applySnapshot(TimeCoreSnapshot snap) {
    machine.applyNativeSnapshot(
      usedToday: snap.usedToday,
      thresholdProgress: snap.thresholdProgress,
      exemptionsUsedToday: snap.exemptionsUsedToday,
      isScreenOn: snap.isScreenOn,
      resting: snap.resting,
      restEndsAt: snap.restEndsAt,
    );
    _todayRestCount = snap.restCount;
    _todayRestExemptions = snap.restExemptions;
    _todayRestElapsed = snap.restCompleted;
    if (snap.resting) {
      _restStart = snap.restStart;
      _restPlanned = machine.settings.restDuration;
    } else {
      _restStart = null;
      _restPlanned = null;
    }
  }

  /// 手动休息（原生模式）：转发原生并立即同步，避免等待下一个 tick。
  Future<void> _manualRestViaCore(TimeCore core) async {
    try {
      await core.manualRest();
      _applySnapshot(await core.snapshot());
    } catch (_) {
      machine.restNow();
    }
  }

  /// 休息期豁免通过（原生模式）：转发原生并立即同步。
  Future<void> _consumeExemptionViaCore(TimeCore core) async {
    try {
      await core.consumeExemption();
      _applySnapshot(await core.snapshot());
    } catch (_) {
      machine.endRestEarly();
    }
  }

  AppPhase get phase => machine.state.phase;

  /// 当日触发休息（进入休息页）的次数，跨自然日自动归零。
  int get todayRestCount => _todayRestCount;

  /// 当日通过答题成功豁免休息的累计次数，跨自然日自动归零。
  int get todayRestExemptions => _todayRestExemptions;

  /// 本机管理密码是否已设置（设置后进入设置与题库需先验证）。
  bool get hasAdminPassword {
    final hash = machine.settings.adminPasswordHash;
    return hash != null && hash.isNotEmpty;
  }

  /// 校验输入的管理密码是否正确；未设置密码时恒为 false。
  bool verifyAdminPassword(String input) {
    return hasAdminPassword &&
        _hashAdminPassword(input) == machine.settings.adminPasswordHash;
  }

  /// 设置/修改（[newPassword] 非空）或清除（null）本机管理密码。
  ///
  /// 只存加盐哈希不存明文；写回 DB 由 [appSettingsRepo] 负责（可空）。
  void updateAdminPassword(String? newPassword) {
    final hash =
        newPassword == null ? null : _hashAdminPassword(newPassword);
    machine.updateSettings(
      machine.settings.copyWith(adminPasswordHash: hash),
    );
    appSettingsRepo?.upsert(machine.settings).catchError((_) {});
    notifyListeners();
  }

  /// 轻量加盐哈希（FNV-1a 64 位）。
  ///
  /// 威胁模型是防止儿童在设备上随手改配置/翻答案，而非抵御离线破解，
  /// 因此不引入额外加密依赖；哈希只保证不明文落库。
  static String _hashAdminPassword(String password) {
    const salt = 'stm-admin-v1:';
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final unit in utf8.encode(salt + password)) {
      hash = ((hash ^ unit) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// 当日累计"未用本机"时长：已完成休息的实际时长 + 当前休息已进行的时长。
  Duration get todayRestDuration {
    var total = _todayRestElapsed;
    if (phase == AppPhase.resting) {
      final start = _restStart;
      if (start != null) total += _clock().difference(start);
    }
    return total < Duration.zero ? Duration.zero : total;
  }

  /// 取日期零点。
  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 跨自然日时归零当日休息统计；若跨天瞬间仍有进行中的休息（有起点），
  /// 把它带入新一天（次数记 1，起点钳到新一天零点）。
  /// 注意：阶段切换进入 resting 时 [machine] 已先行迁移、但 [_restStart]
  /// 尚未设置（为 null），那种情况只归零，计数由调用方随后 +1。
  void _rolloverRestStatsIfNeeded() {
    final day = _dayOf(_clock());
    if (day == _restStatsDay) return;
    _restStatsDay = day;
    _todayRestCount = 0;
    _todayRestElapsed = Duration.zero;
    _todayRestExemptions = 0;
    if (machine.state.phase == AppPhase.resting) {
      final start = _restStart;
      if (start != null) {
        _todayRestCount = 1;
        if (start.isBefore(day)) _restStart = day;
      }
    }
  }

  /// 状态机阶段变化时的回调：进入 quiz 时抽题，离开时重置答题 UI 状态。
  /// 同时记录休息会话（rest_session）的起止。
  void _onMachinePhaseChange() {
    // 原生权威模式：干预与当日休息统计由原生核心负责，Dart 只做会话落库。
    final native = timeCore != null;
    final phase = machine.state.phase;
    final previousPhase = _lastPhase;
    // 离开 resting 阶段：落库一条休息会话。
    if (previousPhase == AppPhase.resting && phase != AppPhase.resting) {
      _flushRestSession(naturalCompletion: !_restEndedEarly);
      _restEndedEarly = false;
    }
    // 进入 resting 阶段：记录起点与计划时长（供会话落库）；本地模式下
    // 额外累计当日次数。
    if (phase == AppPhase.resting && previousPhase != AppPhase.resting) {
      if (!native) {
        _rolloverRestStatsIfNeeded();
        _todayRestCount++;
      }
      _restStart = _clock();
      _restPlanned = machine.settings.restDuration;
    }
    _lastPhase = phase;

    // 原生权威模式下改由 TimeCoreHost.applyEffect 负责，Dart 不再重复请求。
    if (!native) {
      final bridge = interventionBridge;
      if (phase == AppPhase.quiz && previousPhase != AppPhase.quiz) {
        unawaited(bridge?.request(InterventionPhase.quiz));
      } else if (phase == AppPhase.resting &&
          previousPhase != AppPhase.resting) {
        unawaited(bridge?.request(InterventionPhase.resting));
        unawaited(bridge?.startScreenPinning());
      } else if (phase == AppPhase.tracking) {
        if (previousPhase == AppPhase.quiz) {
          // 答题页本身不锁定屏幕，只需撤销干预通知。
          unawaited(bridge?.dismiss());
        } else if (previousPhase == AppPhase.resting) {
          // 休息结束（自然完成或豁免通过）：撤销干预并退出屏幕固定，
          // 之后恢复自由切换应用。
          unawaited(bridge?.dismiss());
          unawaited(bridge?.stopScreenPinning());
        }
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
    if (!native) {
      // 阶段变化（尤其进入/离开休息）立即固化快照，减小被杀丢失窗口。
      _flushDaySnapshot(force: true);
    }
  }

  /// 把已结束的休息会话写入 DB（仅 [restSessionRepo] 存在时），
  /// 同时把实际时长累计到当日休息统计。
  void _flushRestSession({required bool naturalCompletion}) {
    final planned = _restPlanned;
    final startBeforeRollover = _restStart;
    if (startBeforeRollover == null || planned == null) {
      _restStart = null;
      _restPlanned = null;
      return;
    }
    // 跨天处理可能把起点钳到今日零点，actual 与 DB 记录都只计新一天部分。
    // 原生权威模式下当日休息统计由原生维护，Dart 不再本地累计。
    if (timeCore == null) {
      _rolloverRestStatsIfNeeded();
    }
    final start = _restStart ?? startBeforeRollover;
    final end = _clock();
    final actual = end.difference(start);
    if (timeCore == null) {
      _todayRestElapsed += actual;
    }
    _restStart = null;
    _restPlanned = null;

    final repo = restSessionRepo;
    if (repo == null) return;
    final session = RestSession(
      id: _uuid.v4(),
      startedAt: start,
      endedAt: end,
      plannedDuration: planned,
      actualDuration: actual,
      completed: naturalCompletion,
    );
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
    if (phase != AppPhase.tracking) return;
    final core = timeCore;
    if (core == null) {
      machine.restNow();
      return;
    }
    unawaited(_manualRestViaCore(core));
  }

  /// 退出前台到后台继续运行（不销毁进程，监控与计时不受影响）。
  ///
  /// Android 走 `Activity.moveTaskToBack(true)`（等同按 Home）；
  /// 桌面/Web/测试（[monitor] 为 null）静默 no-op。
  Future<void> moveToBackground() async {
    try {
      await monitor?.moveToBack();
    } on MissingPluginException {
      // 通道未注册的旧引擎/非 Android 平台：忽略。
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
    // 同步给原生权威计时核心（后台重启后按新配置生效）。
    final core = timeCore;
    if (core != null) {
      unawaited(core.configure(machine.settings).catchError((_) {}));
    }
  }

  /// 平台层上报亮灭屏。结束当前亮屏会话并落库（灭屏时），
  /// 亮屏时开启新会话。无 [screenSessionRepo] 时仅转发给状态机。
  void reportScreenOn(bool isOn) {
    if (timeCore != null) {
      // 原生权威模式：屏幕状态由原生核心维护，此处仅记录屏幕会话边界。
      if (isOn) {
        _screenSessionStart = _clock();
        _currentScreenSessionId = _uuid.v4();
        _screenExemptions = 0;
        _screenQuizCorrect = 0;
        _screenQuizWrong = 0;
      } else {
        _flushScreenSession();
      }
      return;
    }
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
      // 灭屏后当日亮屏累计定格，立即写一次快照。
      _flushDaySnapshot(force: true);
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
      final core = timeCore;
      if (core == null) {
        _todayRestExemptions++;
        // 消耗额度并触发阶段变化，页面自动切回计时。
        machine.endRestEarly();
      } else {
        // 原生权威模式：转发原生消耗额度并结束休息（统计由原生维护）。
        unawaited(_consumeExemptionViaCore(core));
      }
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
    // 应用退出时落库当前亮屏会话（若仍进行中）并固化当日快照。
    _flushScreenSession();
    _flushDaySnapshot(force: true);
    super.dispose();
  }
}
