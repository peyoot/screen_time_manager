/// 休息会话记录模型。
///
/// 一次休息会话从进入强制休息阶段开始，到自然结束或豁免提前结束为止。
/// 记录计划时长、实际时长与是否自然完成。只增不改。
library;

/// 一次休息会话的不可变快照。
class RestSession {
  /// 会话唯一标识（UUID）。
  final String id;

  /// 休息开始时刻。
  final DateTime startedAt;

  /// 休息结束时刻。
  final DateTime endedAt;

  /// 计划休息时长（来自配置）。
  final Duration plannedDuration;

  /// 实际休息时长（endedAt - startedAt）。
  final Duration actualDuration;

  /// 是否自然完成（true）还是通过答题豁免提前结束（false）。
  final bool completed;

  const RestSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedDuration,
    required this.actualDuration,
    required this.completed,
  });

  @override
  bool operator ==(Object other) =>
      other is RestSession &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.plannedDuration == plannedDuration &&
      other.actualDuration == actualDuration &&
      other.completed == completed;

  @override
  int get hashCode =>
      Object.hash(id, startedAt, endedAt, plannedDuration, actualDuration,
          completed);

  @override
  String toString() => 'RestSession(id: $id, planned: $plannedDuration, '
      'actual: $actualDuration, completed: $completed)';
}
