import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/models/question_bank.dart';

void main() {
  Map<String, dynamic> questionJson(String id, {int correctIndex = 0}) => {
    'id': id,
    'prompt': '题目 $id',
    'options': ['A', 'B', 'C'],
    'correctIndex': correctIndex,
  };

  Map<String, dynamic> bankJson({
    String id = 'b1',
    String name = '基础题库',
    int questionCount = 5,
  }) => {
    'id': id,
    'name': name,
    'questions': [
      for (var i = 0; i < questionCount; i++) questionJson('q$i'),
    ],
  };

  group('QuestionBank.fromJson', () {
    test('合法 JSON 可以构造题库', () {
      final bank = QuestionBank.fromJson(bankJson());
      expect(bank.id, 'b1');
      expect(bank.name, '基础题库');
      expect(bank.questions.length, 5);
      expect(bank.isNotEmpty, isTrue);
    });

    test('JSON 往返保持相等', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 3));
      expect(QuestionBank.fromJson(bank.toJson()), bank);
    });

    test('空题库合法（isEmpty 为 true）', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 0));
      expect(bank.isEmpty, isTrue);
      expect(bank.questions, isEmpty);
    });

    test('题目 id 重复抛出 FormatException', () {
      final json = bankJson();
      (json['questions'] as List).add(questionJson('q0'));
      expect(() => QuestionBank.fromJson(json), throwsFormatException);
    });

    test('questions 字段缺失抛出 FormatException', () {
      expect(
        () => QuestionBank.fromJson({'id': 'b', 'name': 'n'}),
        throwsFormatException,
      );
    });

    test('parse 静态方法等价于 fromJson', () {
      final json = bankJson();
      expect(QuestionBank.parse(json), QuestionBank.fromJson(json));
    });
  });

  group('QuestionBank.drawRandom', () {
    test('抽取数量正确且不重复', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 5));
      final drawn = bank.drawRandom(3, random: Random(42));
      expect(drawn.length, 3);
      expect(drawn.map((q) => q.id).toSet().length, 3);
      for (final q in drawn) {
        expect(bank.questions.contains(q), isTrue);
      }
    });

    test('相同随机种子产生相同结果（可复现）', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 5));
      final a = bank.drawRandom(3, random: Random(7));
      final b = bank.drawRandom(3, random: Random(7));
      expect(a, b);
    });

    test('不同种子通常产生不同顺序', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 5));
      final a = bank.drawRandom(5, random: Random(1));
      final b = bank.drawRandom(5, random: Random(2));
      expect(a, isNot(b));
    });

    test('抽取全部题目时顺序随机且包含全集', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 5));
      final drawn = bank.drawRandom(5, random: Random(42));
      expect(drawn.toSet(), bank.questions.toSet());
    });

    test('空题库抽题抛出 StateError', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 0));
      expect(() => bank.drawRandom(1), throwsStateError);
    });

    test('抽取数量非法抛出 ArgumentError', () {
      final bank = QuestionBank.fromJson(bankJson(questionCount: 2));
      expect(() => bank.drawRandom(0), throwsArgumentError);
      expect(() => bank.drawRandom(3), throwsArgumentError);
    });
  });

  group('QuestionBank 其他', () {
    test('copyWith 只覆盖指定字段', () {
      final bank = QuestionBank.fromJson(bankJson());
      final next = bank.copyWith(name: '新名字');
      expect(next.name, '新名字');
      expect(next.id, bank.id);
      expect(next.questions, bank.questions);
    });
  });
}
