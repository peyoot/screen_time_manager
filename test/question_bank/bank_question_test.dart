import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';

void main() {
  group('BankQuestion 构造', () {
    test('自动生成进程内唯一 id', () {
      final a = BankQuestion(question: 'q', answer: 'a');
      final b = BankQuestion(question: 'q', answer: 'a');
      expect(a.id, isNot(b.id));
    });

    test('题干或答案为空抛出 ArgumentError', () {
      expect(
        () => BankQuestion(question: '  ', answer: 'a'),
        throwsArgumentError,
      );
      expect(
        () => BankQuestion(question: 'q', answer: ''),
        throwsArgumentError,
      );
    });
  });

  group('BankQuestion.fromJson', () {
    test('合法 JSON 与 toJson 往返', () {
      final q = BankQuestion.fromJson({
        'question': '1+1等于几？',
        'answer': '2',
        'hint': '加法',
      });
      expect(q.question, '1+1等于几？');
      expect(q.answer, '2');
      expect(q.hint, '加法');

      final decoded = BankQuestion.fromJson(q.toJson());
      expect(decoded.question, q.question);
      expect(decoded.answer, q.answer);
      expect(decoded.hint, q.hint);
    });

    test('hint 缺省为 null', () {
      final q = BankQuestion.fromJson({'question': 'q', 'answer': 'a'});
      expect(q.hint, isNull);
      expect(q.toJson().containsKey('hint'), isFalse);
    });

    test('字段缺失或类型非法抛出 FormatException', () {
      expect(() => BankQuestion.fromJson({}), throwsFormatException);
      expect(
        () => BankQuestion.fromJson({'question': 'q'}),
        throwsFormatException,
      );
      expect(
        () => BankQuestion.fromJson({'question': 1, 'answer': 'a'}),
        throwsFormatException,
      );
      expect(
        () => BankQuestion.fromJson({
          'question': 'q',
          'answer': 'a',
          'hint': 2,
        }),
        throwsFormatException,
      );
    });
  });

  group('matchesAnswer', () {
    test('忽略首尾空白与大小写', () {
      final q = BankQuestion(question: 'q', answer: 'Hello');
      expect(q.matchesAnswer(' hello '), isTrue);
      expect(q.matchesAnswer('HELLO'), isTrue);
      expect(q.matchesAnswer('world'), isFalse);
    });
  });
}
