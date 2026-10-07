import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/state_machine/quiz_session.dart';

void main() {
  List<Question> buildQuestions(int n) => [
    for (var i = 0; i < n; i++)
      Question(
        id: 'q$i',
        prompt: '题目 $i',
        options: const ['错', '对', '错'],
        correctIndex: 1,
      ),
  ];

  test('初始会话没有任何作答', () {
    final s = QuizSession(
      questions: buildQuestions(3),
      requiredCorrectCount: 2,
    );
    expect(s.currentIndex, 0);
    expect(s.answeredCount, 0);
    expect(s.correctCount, 0);
    expect(s.isComplete, isFalse);
    expect(s.passed, isFalse);
  });

  test('逐题作答并统计答对数', () {
    final s = QuizSession(
      questions: buildQuestions(3),
      requiredCorrectCount: 2,
    );

    final s1 = s.answer(1); // 对
    expect(s1.currentIndex, 1);
    expect(s1.correctCount, 1);
    expect(s1.isComplete, isFalse);

    final s2 = s1.answer(0); // 错
    expect(s2.currentIndex, 2);
    expect(s2.correctCount, 1);

    final s3 = s2.answer(1); // 对
    expect(s3.isComplete, isTrue);
    expect(s3.currentIndex, -1);
    expect(s3.currentQuestion, isNull);
    expect(s3.correctCount, 2);
    expect(s3.passed, isTrue);
  });

  test('答对数不足则判定未通过', () {
    var s = QuizSession(
      questions: buildQuestions(3),
      requiredCorrectCount: 2,
    );
    s = s.answer(0).answer(1).answer(0);
    expect(s.isComplete, isTrue);
    expect(s.correctCount, 1);
    expect(s.passed, isFalse);
  });

  test('单次作答不改变原会话（不可变）', () {
    final s = QuizSession(
      questions: buildQuestions(2),
      requiredCorrectCount: 1,
    );
    final next = s.answer(1);
    expect(s.answeredCount, 0);
    expect(next.answeredCount, 1);
  });

  test('全部作答完再作答抛出 StateError', () {
    var s = QuizSession(
      questions: buildQuestions(1),
      requiredCorrectCount: 1,
    );
    s = s.answer(1);
    expect(() => s.answer(1), throwsStateError);
  });

  test('选项下标越界抛出 RangeError', () {
    final s = QuizSession(
      questions: buildQuestions(1),
      requiredCorrectCount: 1,
    );
    expect(() => s.answer(3), throwsRangeError);
  });

  test('非法构造参数抛出 ArgumentError', () {
    expect(
      () => QuizSession(questions: const [], requiredCorrectCount: 1),
      throwsArgumentError,
    );
    expect(
      () => QuizSession(
        questions: buildQuestions(2),
        requiredCorrectCount: 3,
      ),
      throwsArgumentError,
    );
  });
}
