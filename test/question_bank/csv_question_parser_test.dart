import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/question_bank/csv_question_parser.dart';

void main() {
  group('parseCsvQuestions', () {
    test('解析基础三列数据', () {
      final questions = parseCsvQuestions(
        'question,answer,hint\n1+1等于几？,2,加法\n水的沸点,100℃,标准大气压',
      );
      expect(questions.length, 2);
      expect(questions[0].question, '1+1等于几？');
      expect(questions[0].answer, '2');
      expect(questions[0].hint, '加法');
      expect(questions[1].hint, '标准大气压');
    });

    test('双引号包裹含逗号的字段', () {
      final questions = parseCsvQuestions(
        'question,answer,hint\n"问,题","答,案",提示',
      );
      expect(questions.single.question, '问,题');
      expect(questions.single.answer, '答,案');
      expect(questions.single.hint, '提示');
    });

    test('字段内双引号转义（""）', () {
      final questions = parseCsvQuestions(
        'question,answer,hint\n"他说：""你好""",你也好,',
      );
      expect(questions.single.question, '他说："你好"');
      expect(questions.single.hint, isNull);
    });

    test('hint 列可选（两列表头）', () {
      final questions = parseCsvQuestions('question,answer\n甲,乙');
      expect(questions.single.question, '甲');
      expect(questions.single.answer, '乙');
      expect(questions.single.hint, isNull);
    });

    test('忽略额外列与空 hint 单元格', () {
      final questions = parseCsvQuestions(
        'question,answer,hint,extra\nq,a,,x',
      );
      expect(questions.single.hint, isNull);
    });

    test('表头大小写与空白不敏感', () {
      final questions = parseCsvQuestions(' Question , ANSWER , Hint \nq,a,h');
      expect(questions.single.answer, 'a');
    });

    test('处理 CRLF 换行与 UTF-8 BOM', () {
      final questions = parseCsvQuestions(
        '\uFEFFquestion,answer,hint\r\nq1,a1,h1\r\nq2,a2,h2\r\n',
      );
      expect(questions.length, 2);
      expect(questions.last.question, 'q2');
    });

    test('跳过空行；表头后无数据行返回空列表', () {
      expect(
        parseCsvQuestions('question,answer\n\nq,a\n\n').single.question,
        'q',
      );
      expect(parseCsvQuestions('question,answer\n'), isEmpty);
    });

    test('内容为空抛出 FormatException', () {
      expect(() => parseCsvQuestions(''), throwsFormatException);
      expect(() => parseCsvQuestions('   \n  '), throwsFormatException);
    });

    test('表头缺少 question/answer 列抛出 FormatException', () {
      expect(() => parseCsvQuestions('q,a\n1,2'), throwsFormatException);
      expect(
        () => parseCsvQuestions('question,hint\nq,h'),
        throwsFormatException,
      );
    });

    test('行内 question/answer 为空抛出 FormatException', () {
      expect(
        () => parseCsvQuestions('question,answer\n只有题干'),
        throwsFormatException,
      );
      expect(
        () => parseCsvQuestions('question,answer\n,答案'),
        throwsFormatException,
      );
    });

    test('未闭合引号抛出 FormatException', () {
      expect(
        () => parseCsvQuestions('question,answer\n"未闭合,a'),
        throwsFormatException,
      );
    });

    test('字段中间出现引号抛出 FormatException', () {
      expect(
        () => parseCsvQuestions('question,answer\nab"c,a'),
        throwsFormatException,
      );
    });
  });
}
