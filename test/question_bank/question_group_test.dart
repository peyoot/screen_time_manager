import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_group.dart';

void main() {
  const validJson = '''
  {
    "groupName": "安全知识",
    "type": "input",
    "questions": [
      {"question": "火警电话？", "answer": "119", "hint": "三位数"},
      {"question": "水的化学式？", "answer": "H2O"}
    ]
  }''';

  group('QuestionGroup.fromJson', () {
    test('解析完整字段', () {
      final group = QuestionGroup.fromJson({
        'groupName': '常识',
        'type': 'input',
        'enabled': false,
        'questions': [
          {'question': 'q', 'answer': 'a', 'hint': 'h'},
        ],
      });
      expect(group.name, '常识');
      expect(group.type, 'input');
      expect(group.enabled, isFalse);
      expect(group.questions.single.hint, 'h');
    });

    test('type/enabled 缺省值', () {
      final group = QuestionGroup.fromJson({
        'groupName': '常识',
        'questions': [
          {'question': 'q', 'answer': 'a'},
        ],
      });
      expect(group.type, 'input');
      expect(group.enabled, isTrue);
    });

    test('允许空 questions 数组', () {
      final group = QuestionGroup.fromJson(
        {'groupName': '空组', 'questions': []},
      );
      expect(group.questions, isEmpty);
    });
  });

  group('QuestionGroup.parse', () {
    test('解析 JSON 文本', () {
      final group = QuestionGroup.parse(validJson);
      expect(group.name, '安全知识');
      expect(group.questions.length, 2);
      expect(group.questions.first.answer, '119');
    });

    test('JSON 语法错误抛出 FormatException', () {
      expect(() => QuestionGroup.parse('{ groupName: '), throwsFormatException);
    });

    test('顶层不是对象抛出 FormatException', () {
      expect(() => QuestionGroup.parse('[1,2]'), throwsFormatException);
    });

    test('缺少 groupName / questions 抛出 FormatException', () {
      expect(
        () => QuestionGroup.parse('{"type":"input","questions":[]}'),
        throwsFormatException,
      );
      expect(
        () => QuestionGroup.parse('{"groupName":"g"}'),
        throwsFormatException,
      );
    });

    test('题目缺 answer 抛出 FormatException', () {
      expect(
        () => QuestionGroup.parse(
          '{"groupName":"g","questions":[{"question":"q"}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('QuestionGroup 其他', () {
    test('构造时分组名不能为空', () {
      expect(
        () => QuestionGroup(name: '  ', questions: const []),
        throwsArgumentError,
      );
    });

    test('copyWith 只覆盖指定字段', () {
      final q = BankQuestion(question: 'q', answer: 'a');
      final group = QuestionGroup(name: '旧名', questions: [q]);
      final next = group.copyWith(name: '新名', enabled: false);
      expect(next.id, group.id);
      expect(next.name, '新名');
      expect(next.enabled, isFalse);
      expect(next.type, 'input');
      expect(next.questions.single, q);
    });

    test('questions 列表不可变', () {
      final group = QuestionGroup(name: 'g', questions: const []);
      expect(() => group.questions.add(BankQuestion(question: 'q', answer: 'a')),
          throwsUnsupportedError);
    });
  });
}
