/// 屏幕时间状态机对外暴露的不可变状态快照。
library;

import '../models/daily_usage.dart';
import 'app_phase.dart';
import 'quiz_session.dart';

/// 状态机在某一时刻的完整状态。
///
/// 全部字段只读，状态机每次迁移都会整体替换该快照，
/// UI 层可直接针对快照做等值判断与重建。
class ScreenTimeState {
  /// 当前所处阶段。
  final AppPhase phase;

  /// 屏幕当前是否点亮。
  final bool isScreenOn;

  /// 当日亮屏用量记录。
  final DailyUsage dailyUsage;

  /// 自上一次豁免通过（或休息结束）以来累计的亮屏时长，
  /// 达到配置阈值后触发新一轮答题。
  final Duration sinceLastGrant;

  /// 触发下一轮答题所需的亮屏时长阈值（来自当前配置）。
  final Duration quizInterval;

  /// 第几次触发豁免答题（从 0 开始，每次进入答题递增），
  /// 可用于统计与 UI 展示。
  final int quizRound;

  /// 当前进行中的答题会话，仅在 [AppPhase.quiz] 阶段非空。
  final QuizSession? quiz;

  /// 强制休息的结束时刻，仅在 [AppPhase.resting] 阶段非空。
  final DateTime? restEndsAt;

  const ScreenTimeState({
    required this.phase,
    required this.isScreenOn,
    required this.dailyUsage,
    required this.sinceLastGrant,
    required this.quizInterval,
    required this.quizRound,
    this.quiz,
    this.restEndsAt,
  });

  /// 创建初始状态：计时阶段、零用量、无答题会话。
  factory ScreenTimeState.initial({
    required DateTime now,
    required Duration quizInterval,
    bool isScreenOn = false,
  }) {
    return ScreenTimeState(
      phase: AppPhase.tracking,
      isScreenOn: isScreenOn,
      dailyUsage: DailyUsage.today(now),
      sinceLastGrant: Duration.zero,
      quizInterval: quizInterval,
      quizRound: 0,
    );
  }

  /// 当日累计亮屏时长（[dailyUsage] 的便捷访问）。
  Duration get usedToday => dailyUsage.accumulated;

  /// 距离下一轮答题还需累计的亮屏时长（不会为负）。
  Duration get remainingToQuiz {
    final remaining = quizInterval - sinceLastGrant;
    return remaining < Duration.zero ? Duration.zero : remaining;
  }

  /// 当前是否正在豁免答题。
  bool get isInQuiz => phase == AppPhase.quiz;

  /// 当前是否处于全屏休息。
  bool get isResting => phase == AppPhase.resting;

  ScreenTimeState copyWith({
    AppPhase? phase,
    bool? isScreenOn,
    DailyUsage? dailyUsage,
    Duration? sinceLastGrant,
    Duration? quizInterval,
    int? quizRound,
    Object? quiz = _sentinel,
    Object? restEndsAt = _sentinel,
  }) {
    return ScreenTimeState(
      phase: phase ?? this.phase,
      isScreenOn: isScreenOn ?? this.isScreenOn,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      sinceLastGrant: sinceLastGrant ?? this.sinceLastGrant,
      quizInterval: quizInterval ?? this.quizInterval,
      quizRound: quizRound ?? this.quizRound,
      quiz: quiz == _sentinel ? this.quiz : quiz as QuizSession?,
      restEndsAt: restEndsAt == _sentinel
          ? this.restEndsAt
          : restEndsAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenTimeState &&
      other.phase == phase &&
      other.isScreenOn == isScreenOn &&
      other.dailyUsage == dailyUsage &&
      other.sinceLastGrant == sinceLastGrant &&
      other.quizInterval == quizInterval &&
      other.quizRound == quizRound &&
      other.quiz == quiz &&
      other.restEndsAt == restEndsAt;

  @override
  int get hashCode =>
      Object.hash(phase, isScreenOn, dailyUsage, sinceLastGrant, quizInterval,
          quizRound, quiz, restEndsAt);

  @override
  String toString() => 'ScreenTimeState(phase: $phase, screenOn: $isScreenOn, '
      'usedToday: $usedToday, sinceLastGrant: $sinceLastGrant, '
      'round: $quizRound)';
}

/// 用于 [ScreenTimeState.copyWith] 区分“未传参”与“显式传 null”。
const Object _sentinel = Object();
