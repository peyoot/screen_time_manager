/// 一轮豁免答题的会话状态。
library;

import '../models/question.dart';

/// 一次豁免答题中抽中的题目集合以及用户的作答记录。
///
/// 不可变值对象，每作答一次通过 [answer] 产生新的会话实例，
/// 便于状态机以不可变快照的方式向外暴露状态。
class QuizSession {
  /// 本轮抽到的题目（顺序即作答顺序）。
  final List<Question> questions;

  /// 通过本轮答题所需的最少答对数。
  final int requiredCorrectCount;

  /// 与 [questions] 一一对应的作答记录，`null` 表示尚未作答。
  final List<int?> answers;

  const QuizSession._({
    required this.questions,
    required this.requiredCorrectCount,
    required this.answers,
  });

  /// 基于抽到的题目开启一轮答题。
  factory QuizSession({
    required List<Question> questions,
    required int requiredCorrectCount,
  }) {
    if (questions.isEmpty) {
      throw ArgumentError.value(questions, 'questions', '答题轮次不能为空');
    }
    if (requiredCorrectCount <= 0 ||
        requiredCorrectCount > questions.length) {
      throw ArgumentError.value(
        requiredCorrectCount,
        'requiredCorrectCount',
        '必须位于 [1, questions.length] 区间内',
      );
    }
    return QuizSession._(
      questions: List.unmodifiable(questions),
      requiredCorrectCount: requiredCorrectCount,
      answers: List<int?>.filled(questions.length, null),
    );
  }

  /// 当前待作答的题目下标；全部作答完毕返回 -1。
  int get currentIndex => answers.indexOf(null);

  /// 当前待作答的题目；全部作答完毕返回 `null`。
  Question? get currentQuestion =>
      currentIndex == -1 ? null : questions[currentIndex];

  /// 是否已作答完全部题目。
  bool get isComplete => !answers.contains(null);

  /// 已作答的题数。
  int get answeredCount => answers.where((a) => a != null).length;

  /// 当前累计答对数。
  int get correctCount {
    var count = 0;
    for (var i = 0; i < questions.length; i++) {
      final a = answers[i];
      if (a != null && questions[i].isCorrect(a)) count++;
    }
    return count;
  }

  /// 是否本轮通过（全部作答完且答对数达标）。
  bool get passed => isComplete && correctCount >= requiredCorrectCount;

  /// 对当前题目选择 [optionIndex]，返回记录了该答案的新会话。
  ///
  /// 已全部作答完时抛出 [StateError]；下标越界时抛出 [RangeError]。
  QuizSession answer(int optionIndex) {
    if (isComplete) {
      throw StateError('本轮答题已结束，不能继续作答');
    }
    if (optionIndex < 0 || optionIndex >= currentQuestion!.options.length) {
      throw RangeError.index(
        optionIndex,
        currentQuestion!.options,
        'optionIndex',
      );
    }
    final nextAnswers = List<int?>.of(answers);
    nextAnswers[currentIndex] = optionIndex;
    return QuizSession._(
      questions: questions,
      requiredCorrectCount: requiredCorrectCount,
      answers: nextAnswers,
    );
  }

  @override
  String toString() => 'QuizSession(total: ${questions.length}, '
      'answered: $answeredCount, correct: $correctCount, '
      'required: $requiredCorrectCount, complete: $isComplete)';
}
