/// 当日运行状态快照模型。
library;

/// 当日运行状态快照：进程被杀（划掉应用/系统回收）重启后
/// 恢复"当天数据延续性"的数据载体。
///
/// 控制器运行期按约 5 秒节流把状态机当日累计与当日休息统计
/// 写入 `day_snapshot` 表（每天一行）；启动时读回并经
/// `ScreenTimeMachine.restoreDay` 移植，避免计数计时从零开始。
class DaySnapshot {
  /// 快照对应的自然日（当地时区零点）。
  final DateTime day;

  /// 今日累计亮屏时长（状态机 dailyUsage.accumulated）。
  final Duration screenTime;

  /// 当前阈值进度（自上次豁免通过/休息结束以来的累计）。
  final Duration thresholdProgress;

  /// 今日已用豁免次数（状态机口径，含亮屏阈值豁免与休息期豁免）。
  final int exemptionsUsedToday;

  /// 今日触发休息次数（含进行中的一次）。
  final int restCount;

  /// 今日累计"未用本机"时长（含进行中休息的已流逝部分）。
  final Duration restElapsed;

  /// 今日答题豁免休息次数（控制器口径，自然完成休息也不重置）。
  final int restExemptions;

  /// 进行中休息的截止时刻；不在休息期时为 null。
  /// 存取均以 UTC 序列化，比较不受 DateTime.isUtc 标志影响。
  final DateTime? restEndsAt;

  const DaySnapshot({
    required this.day,
    this.screenTime = Duration.zero,
    this.thresholdProgress = Duration.zero,
    this.exemptionsUsedToday = 0,
    this.restCount = 0,
    this.restElapsed = Duration.zero,
    this.restExemptions = 0,
    this.restEndsAt,
  });

  /// 任意时刻对应的快照键（当地时区 `yyyy-MM-dd`，与 DailyUsage 一致）。
  static String keyFor(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  /// 本快照的日键。
  String get dayKey => keyFor(day);

  /// 本快照是否属于 [dt] 所在的自然日（跨天后旧快照应被忽略）。
  bool isForDay(DateTime dt) => keyFor(dt) == dayKey;

  @override
  String toString() =>
      'DaySnapshot($dayKey, screen: $screenTime, threshold: $thresholdProgress, '
      'exemptions: $exemptionsUsedToday, rest: $restCount/$restElapsed, '
      'restExemptions: $restExemptions, restEndsAt: $restEndsAt)';
}
