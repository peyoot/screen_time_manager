/// 屏幕时间管理核心状态机。
///
/// 纯 Dart 逻辑（仅依赖 Flutter foundation 的 [ChangeNotifier]），
/// 不直接监听任何平台事件：亮灭屏、时间推进由平台层/定时器通过
/// [setScreenOn] 与 [tick] 驱动，从而保证逻辑可在单元测试中
/// 以虚拟时钟确定性地验证。
library;

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/daily_usage.dart';
import '../models/question_bank.dart';
import 'app_phase.dart';
import 'screen_time_state.dart';

/// 亮屏计时 → 豁免答题 → 全屏休息 的核心状态机。
class ScreenTimeMachine extends ChangeNotifier {
  AppSettings _settings;
  QuestionBank? _bank;
  final DateTime Function() _clock;
  DateTime _lastTickAt;

  ScreenTimeState _state;

  /// 当前不可变状态快照。
  ScreenTimeState get state => _state;

  /// 当前生效配置。
  AppSettings get settings => _settings;

  /// 当前题库（可能尚未导入）。
  QuestionBank? get questionBank => _bank;

  /// 今日剩余可用的答题豁免次数（不会为负）。
  int get remainingExemptions {
    final left = _settings.dailyExemptionLimit - _state.exemptionsUsedToday;
    return left < 0 ? 0 : left;
  }

  /// 当前是否还能通过答题豁免（亮屏阈值或休息期均以此判定）。
  bool get canExempt => remainingExemptions > 0;

  /// 创建状态机。
  ///
  /// - [settings]：触发阈值与答题规则；
  /// - [questionBank]：可选的初始题库（当前到点直接进休息，不再抽题）；
  /// - [clock]：可注入时钟，测试中传入虚拟时钟即可避免真实等待；
  /// - [initiallyScreenOn]：创建时屏幕是否点亮。
  factory ScreenTimeMachine({
    required AppSettings settings,
    QuestionBank? questionBank,
    DateTime Function()? clock,
    bool initiallyScreenOn = false,
  }) {
    final time = clock ?? DateTime.now;
    final now = time();
    return ScreenTimeMachine._(
      settings,
      questionBank,
      time,
      now,
      ScreenTimeState.initial(
        now: now,
        quizInterval: settings.quizInterval,
        isScreenOn: initiallyScreenOn,
      ),
    );
  }

  ScreenTimeMachine._(
    this._settings,
    this._bank,
    this._clock,
    this._lastTickAt,
    this._state,
  );

  /// 更新配置（例如用户调整阈值）。新一轮阈值即时生效，
  /// 已开始的答题轮次不受影响。
  ///
  /// 若当前处于计时阶段且既有进度已达到新阈值，会立即触发
  /// 一轮答题（或在无可用题库时进入休息）。
  void updateSettings(AppSettings settings) {
    _settings = settings;
    _state = _state.copyWith(quizInterval: settings.quizInterval);
    if (_state.phase == AppPhase.tracking &&
        _state.sinceLastGrant >= settings.quizInterval) {
      _enterQuizOrRest(_clock());
    }
    notifyListeners();
  }

  /// 替换/导入题库；当前正在进行的答题轮次不受影响。
  void setQuestionBank(QuestionBank? bank) {
    _bank = bank;
  }

  /// 上报亮屏（`true`）/灭屏（`false`）事件。
  ///
  /// 亮屏时刻会重置计时起点，避免把灭屏期间误计为亮屏时长
  /// （平台层可能在灭屏时不上报 tick）。
  void setScreenOn(bool isScreenOn) {
    if (_state.isScreenOn == isScreenOn) return;
    _state = _state.copyWith(isScreenOn: isScreenOn);
    _lastTickAt = _clock();
    notifyListeners();
  }

  /// 推进时间。建议平台层在前台服务/长时任务中每秒调用一次。
  ///
  /// - [AppPhase.tracking] 且屏幕点亮：累计亮屏时长，达阈值触发答题；
  /// - [AppPhase.resting]：到达休息结束时刻自动回到计时阶段，
  ///   超出结束时刻的时间若屏幕点亮会计入新一轮时长；
  /// - [AppPhase.quiz]：时间推进不产生任何效果，答题耗时不计时。
  void tick() {
    final now = _clock();
    var delta = now.difference(_lastTickAt);
    if (delta < Duration.zero) delta = Duration.zero;
    _lastTickAt = now;
    _advance(now, delta);
  }

  /// 对当前题目作答（选项下标）。
  ///
  /// 若已是本轮最后一题：答对数达标则豁免通过、回到计时阶段并
  /// 重新累计阈值；否则进入全屏强制休息。
  /// 非答题阶段调用抛出 [StateError]。
  void answerCurrentQuestion(int optionIndex) {
    final session = _state.quiz;
    if (_state.phase != AppPhase.quiz || session == null) {
      throw StateError('当前不在豁免答题阶段，无法作答');
    }

    final nextSession = session.answer(optionIndex);
    if (!nextSession.isComplete) {
      _state = _state.copyWith(quiz: nextSession);
    } else if (nextSession.passed) {
      // 豁免通过：消耗一次今日豁免额度，清空答题会话并重新开始累计。
      _state = _state.copyWith(
        phase: AppPhase.tracking,
        quiz: null,
        sinceLastGrant: Duration.zero,
        exemptionsUsedToday: _state.exemptionsUsedToday + 1,
      );
    } else {
      _enterRest(_clock());
    }
    notifyListeners();
  }

  /// 从计时阶段手动触发一次全屏休息（用户主动点击"立即休息"）。
  ///
  /// 仅在 [AppPhase.tracking] 阶段允许调用；其他阶段抛出 [StateError]。
  /// 休息结束后正常回到计时阶段并重新累计阈值。
  void restNow() {
    if (_state.phase != AppPhase.tracking) {
      throw StateError('仅计时阶段可手动触发休息');
    }
    _enterRest(_clock());
    notifyListeners();
  }

  /// 放弃当前答题，直接进入全屏强制休息。
  /// 非答题阶段调用抛出 [StateError]。
  void giveUpQuiz() {
    if (_state.phase != AppPhase.quiz) {
      throw StateError('当前不在豁免答题阶段，无法放弃答题');
    }
    _enterRest(_clock());
    notifyListeners();
  }

  /// 休息期间通过答题豁免提前结束休息。
  ///
  /// 仅在 [AppPhase.resting] 阶段允许调用；其他阶段抛出 [StateError]。
  /// 今日豁免次数已用完时同样抛出 [StateError]，调用方应先检查 [canExempt]。
  /// 效果与自然休息结束一致：回到计时阶段并重新累计阈值，同时消耗一次额度。
  void endRestEarly() {
    if (_state.phase != AppPhase.resting) {
      throw StateError('当前不在休息阶段，无法豁免休息');
    }
    if (!canExempt) {
      throw StateError('今日豁免次数已用完，无法提前结束休息');
    }
    _state = _state.copyWith(
      phase: AppPhase.tracking,
      restEndsAt: null,
      sinceLastGrant: Duration.zero,
      exemptionsUsedToday: _state.exemptionsUsedToday + 1,
    );
    notifyListeners();
  }

  /// 进程被杀重启后恢复当日进度（配合 day_snapshot 快照表使用）。
  ///
  /// 仅移植状态快照，不做阶段迁移判断之外的处理；恢复"休息中"时
  /// 会照常发出通知，由控制器钩子补齐干预与统计副作用。
  /// - [usedToday]：今日已累计亮屏时长；
  /// - [thresholdProgress]：当前阈值进度；
  /// - [exemptionsUsedToday]：今日已用豁免次数（状态机口径）；
  /// - [restEndsAt]：重启前处于休息期的截止时刻；仅当仍晚于当前时刻
  ///   才恢复为休息中，已过期则按计时阶段继续（该次休息视为已跳过）。
  void restoreDay({
    required Duration usedToday,
    required Duration thresholdProgress,
    int exemptionsUsedToday = 0,
    DateTime? restEndsAt,
  }) {
    final now = _clock();
    var state = ScreenTimeState.initial(
      now: now,
      quizInterval: _settings.quizInterval,
    );
    state = state.copyWith(
      // 恢复不改变亮屏状态：initial 默认灭屏，会误杀进行中的亮屏累计。
      isScreenOn: _state.isScreenOn,
      dailyUsage: state.dailyUsage.addScreenTime(usedToday),
      sinceLastGrant: thresholdProgress,
      exemptionsUsedToday: exemptionsUsedToday,
    );
    if (restEndsAt != null && restEndsAt.isAfter(now)) {
      state = state.copyWith(phase: AppPhase.resting, restEndsAt: restEndsAt);
    }
    _state = state;
    _lastTickAt = now;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------

  /// 根据 [now] 与距上次 tick 的增量 [delta] 推进状态。
  void _advance(DateTime now, Duration delta) {
    // 跨天 tick 的增量横跨两天，无法精确归属，保守起见不计入新的一天。
    final rolledOver = _rolloverIfNeeded(now);
    var changed = rolledOver;

    if (_state.phase == AppPhase.resting) {
      final endsAt = _state.restEndsAt!;
      if (now.isBefore(endsAt)) {
        // 休息未结束：休息期间不产生亮屏时长。
        if (changed) notifyListeners();
        return;
      }
      // 休息结束，回到计时阶段并重新累计阈值；
      // 超过结束时刻的余量在亮屏时计入新一轮。
      //
      // 豁免额度已用尽（0 次）时，完成一次完整休息视为"惩罚结束"，
      // 豁免次数重新充满；通过答题提前结束休息（endRestEarly）不走这里，
      // 因此不会重置。额度上限为 0 时重置结果仍是 0，行为不变。
      final resetExemptions = !canExempt;
      final overflow = now.difference(endsAt);
      _state = _state.copyWith(
        phase: AppPhase.tracking,
        restEndsAt: null,
        sinceLastGrant: Duration.zero,
        exemptionsUsedToday: resetExemptions ? 0 : _state.exemptionsUsedToday,
      );
      changed = true;
      delta = overflow < Duration.zero ? Duration.zero : overflow;
    }

    if (!rolledOver &&
        _state.phase == AppPhase.tracking &&
        _state.isScreenOn &&
        delta > Duration.zero) {
      _accumulate(delta, now);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  /// 累计亮屏时长，达到阈值则直接强制休息（无提醒页中间态）。
  void _accumulate(Duration delta, DateTime now) {
    final nextUsage = _state.dailyUsage.addScreenTime(delta);
    final nextProgress = _state.sinceLastGrant + delta;
    _state = _state.copyWith(
      dailyUsage: nextUsage,
      sinceLastGrant: nextProgress,
    );
    if (nextProgress >= _settings.quizInterval) {
      _enterRest(now);
    }
  }

  /// 到点自动进入全屏强制休息（保留此方法供 quiz 答错/放弃后复用）。
  void _enterQuizOrRest(DateTime now) {
    _enterRest(now);
  }

  /// 进入全屏强制休息，结束时刻为 [now] + 配置的休息时长。
  void _enterRest(DateTime now) {
    _state = _state.copyWith(
      phase: AppPhase.resting,
      quiz: null,
      restEndsAt: now.add(_settings.restDuration),
    );
  }

  /// 跨自然日归零。进行中的答题轮次保留其进度（答题已触发），
  /// 其他阶段阈值进度与当日豁免次数随新一天清零。返回状态是否发生变化。
  bool _rolloverIfNeeded(DateTime now) {
    final usage = _state.dailyUsage;
    if (usage.isSameDay(now)) return false;
    _state = _state.copyWith(
      dailyUsage: DailyUsage.today(now),
      sinceLastGrant:
          _state.phase == AppPhase.quiz
              ? _state.sinceLastGrant
              : Duration.zero,
      exemptionsUsedToday: 0,
    );
    return true;
  }
}
