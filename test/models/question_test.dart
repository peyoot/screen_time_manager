import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/question.dart';

void main() {
  Question buildQuestion() => const Question(
    id: 'q1',
    prompt: '1 + 1 = ?',
    options: ['1', '2', '3', '4'],
    correctIndex: 1,
    explanation: '1 + 1 = 2',
  );

  group('Question.fromJson', () {
    test('合法 JSON 可以构造题目', () {
      final q = Question.fromJson({
        'id': 'q1',
        'prompt': '1 + 1 = ?',
        'options': ['1', '2'],
        'correctIndex': 1,
      });

      expect(q.id, 'q1');
      expect(q.prompt, '1 + 1 = ?');
      expect(q.options, ['1', '2']);
      expect(q.correctIndex, 1);
      expect(q.explanation, isNull);
    });

    test('JSON 往返保持相等', () {
      final q = buildQuestion();
      expect(Question.fromJson(q.toJson()), q);
    });

    test('id 缺失或为空抛出 FormatException', () {
      expect(
        () => Question.fromJson({
          'prompt': 'p',
          'options': ['a', 'b'],
          'correctIndex': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => Question.fromJson({
          'id': '',
          'prompt': 'p',
          'options': ['a', 'b'],
          'correctIndex': 0,
        }),
        throwsFormatException,
      );
    });

    test('选项少于 2 个抛出 FormatException', () {
      expect(
        () => Question.fromJson({
          'id': 'q',
          'prompt': 'p',
          'options': ['only'],
          'correctIndex': 0,
        }),
        throwsFormatException,
      );
    });

    test('correctIndex 越界抛出 FormatException', () {
      expect(
        () => Question.fromJson({
          'id': 'q',
          'prompt': 'p',
          'options': ['a', 'b'],
          'correctIndex': 2,
        }),
        throwsFormatException,
      );
      expect(
        () => Question.fromJson({
          'id': 'q',
          'prompt': 'p',
          'options': ['a', 'b'],
          'correctIndex': -1,
        }),
        throwsFormatException,
      );
    });

    test('选项中存在空字符串抛出 FormatException', () {
      expect(
        () => Question.fromJson({
          'id': 'q',
          'prompt': 'p',
          'options': ['a', ''],
          'correctIndex': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('Question 行为', () {
    test('isCorrect 仅在正确下标处为 true', () {
      final q = buildQuestion();
      expect(q.isCorrect(1), isTrue);
      expect(q.isCorrect(0), isFalse);
      expect(q.isCorrect(2), isFalse);
    });

    test('copyWith 只覆盖指定字段', () {
      final q = buildQuestion();
      final next = q.copyWith(prompt: 'changed');
      expect(next.prompt, 'changed');
      expect(next.id, q.id);
      expect(next.options, q.options);
      expect(next.correctIndex, q.correctIndex);
    });

    test('值相等与 hashCode', () {
      expect(buildQuestion(), buildQuestion());
      expect(buildQuestion().hashCode, buildQuestion().hashCode);
    });
  });
}
