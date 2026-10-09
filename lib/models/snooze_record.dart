/// 豁免明细记录模型。
///
/// 每完成一轮答题豁免（通过或失败）产生一条 [SnoozeRecord]，
/// 关联到当时的亮屏会话，记录本次抽到的题目 id 与对错统计。只增不改。
library;

/// 一次豁免答题的不可变快照。
class SnoozeRecord {
  /// 记录唯一标识（UUID）。
  final String id;

  /// 关联的亮屏会话 id；休息期豁免时可能为 `null`。
  final String? screenSessionId;

  /// 第几轮答题触发（与状态机 quizRound 一致）。
  final int quizRound;

  /// 本次抽到的题目 id 列表，以 JSON 数组文本存储。
  final String questionIdsJson;

  /// 是否豁免成功（答对数达标）。
  final bool passed;

  /// 本次答对题数。
  final int correctCount;

  /// 本次答错题数。
  final int wrongCount;

  const SnoozeRecord({
    required this.id,
    this.screenSessionId,
    required this.quizRound,
    required this.questionIdsJson,
    required this.passed,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is SnoozeRecord &&
      other.id == id &&
      other.screenSessionId == screenSessionId &&
      other.quizRound == quizRound &&
      other.questionIdsJson == questionIdsJson &&
      other.passed == passed &&
      other.correctCount == correctCount &&
      other.wrongCount == wrongCount;

  @override
  int get hashCode =>
      Object.hash(id, screenSessionId, quizRound, questionIdsJson, passed,
          correctCount, wrongCount);

  @override
  String toString() => 'SnoozeRecord(id: $id, round: $quizRound, '
      'passed: $passed, correct: $correctCount, wrong: $wrongCount)';
}
