/// 亮屏会话记录模型。
///
/// 一次亮屏会话从屏幕点亮开始，到熄屏结束。记录起止时间、
/// 本次会话内的豁免次数与答题对错统计。只增不改，写入后不再修改。
library;

/// 一次亮屏会话的不可变快照。
class ScreenSession {
  /// 会话唯一标识（UUID）。
  final String id;

  /// 亮屏开始时刻。
  final DateTime startedAt;

  /// 熄屏结束时刻；会话进行中为 `null`。
  final DateTime? endedAt;

  /// 本次会话内通过答题豁免的次数。
  final int exemptionCount;

  /// 本次会话内答题答对总次数。
  final int quizCorrectCount;

  /// 本次会话内答题答错总次数。
  final int quizWrongCount;

  const ScreenSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.exemptionCount = 0,
    this.quizCorrectCount = 0,
    this.quizWrongCount = 0,
  });

  ScreenSession copyWith({
    DateTime? endedAt,
    int? exemptionCount,
    int? quizCorrectCount,
    int? quizWrongCount,
  }) {
    return ScreenSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      exemptionCount: exemptionCount ?? this.exemptionCount,
      quizCorrectCount: quizCorrectCount ?? this.quizCorrectCount,
      quizWrongCount: quizWrongCount ?? this.quizWrongCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenSession &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.exemptionCount == exemptionCount &&
      other.quizCorrectCount == quizCorrectCount &&
      other.quizWrongCount == quizWrongCount;

  @override
  int get hashCode =>
      Object.hash(id, startedAt, endedAt, exemptionCount, quizCorrectCount,
          quizWrongCount);

  @override
  String toString() => 'ScreenSession(id: $id, started: $startedAt, '
      'ended: $endedAt, exemptions: $exemptionCount)';
}
