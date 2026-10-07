import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';

void main() {
  /// 快捷构造 N 道题。
  List<BankQuestion> buildQuestions(
    String prefix,
    int n, {
    String? answer,
  }) =>
      [
        for (var i = 0; i < n; i++)
          BankQuestion(question: '$prefix$i', answer: answer ?? '答案$i'),
      ];

  group('分组 CRUD', () {
    test('新建/重命名/启停/删除分组', () {
      final service = QuestionBankService();
      final group = service.createGroup('原始名');
      expect(service.groups.single.name, '原始名');

      service.renameGroup(group.id, '新名');
      expect(service.groupById(group.id)!.name, '新名');

      service.setGroupEnabled(group.id, false);
      expect(service.groupById(group.id)!.enabled, isFalse);

      service.removeGroup(group.id);
      expect(service.groups, isEmpty);
      expect(service.groupById(group.id), isNull);
    });

    test('添加与批量删除题目', () {
      final service = QuestionBankService();
      final groupId = service.createGroup('G').id;
      final questions = buildQuestions('q', 3);
      service.addQuestions(groupId, questions);
      expect(service.groupById(groupId)!.questions.length, 3);

      service.removeQuestions(groupId, [questions[0].id, questions[2].id]);
      expect(service.groupById(groupId)!.questions.single, questions[1]);

      // 删除的题同时清理权重与最近抽题记录。
      service.recordAnswer(questions[0].id, correct: false);
      service.addQuestions(groupId, [questions[0]]);
      service.removeQuestions(groupId, [questions[0].id]);
      expect(service.weightOf(questions[0].id), 1);
      expect(service.recentDrawnIds.contains(questions[0].id), isFalse);
    });

    test('导入数据创建新分组', () {
      final service = QuestionBankService();
      final group = service.importIntoNewGroup(
        name: '导入组',
        questions: buildQuestions('q', 2),
      );
      expect(service.groups.single, group);
      expect(group.questions.length, 2);
    });
  });

  group('drawQuestions', () {
    test('只从启用分组中抽取，且一次抽取内不重复', () {
      final service = QuestionBankService();
      final enabled = service.createGroup('启用');
      service.addQuestions(enabled.id, buildQuestions('enabled-', 4));
      final disabled = service.createGroup('停用');
      service.addQuestions(disabled.id, buildQuestions('disabled-', 4));
      service.setGroupEnabled(disabled.id, false);

      final drawn = service.drawQuestions(4, random: Random(42));
      expect(drawn.length, 4);
      expect(drawn.map((q) => q.id).toSet().length, 4);
      expect(
        drawn.every((q) => q.question.startsWith('enabled-')),
        isTrue,
      );
      expect(() => service.drawQuestions(5), throwsArgumentError);
    });

    test('避开最近抽过的题（记忆容量 6，池 12）', () {
      final service = QuestionBankService(recentMemorySize: 6);
      final group = service.createGroup('G');
      service.addQuestions(group.id, buildQuestions('q', 12));

      final rng = Random(1);
      final window = <String>[];
      for (var round = 0; round < 30; round++) {
        final drawn = service.drawQuestions(1, random: rng);
        final id = drawn.single.id;
        expect(
          window.contains(id),
          isFalse,
          reason: '第 $round 次抽到了最近抽过的题',
        );
        window.add(id);
        if (window.length > 6) window.removeAt(0);
      }
      // 记忆容量已打满。
      expect(service.recentDrawnIds.length, 6);
    });

    test('候选不足时放宽最近不重复约束，不会抛错', () {
      final service = QuestionBankService(recentMemorySize: 10);
      final group = service.createGroup('小题库');
      service.addQuestions(group.id, buildQuestions('q', 3));

      for (var round = 0; round < 10; round++) {
        final drawn = service.drawQuestions(2);
        expect(drawn.length, 2);
        expect(drawn.map((q) => q.id).toSet().length, 2);
      }
    });

    test('抽取数量非法或池不足抛出 ArgumentError', () {
      final service = QuestionBankService();
      final group = service.createGroup('G');
      service.addQuestions(group.id, buildQuestions('q', 2));
      expect(() => service.drawQuestions(0), throwsArgumentError);
      expect(() => service.drawQuestions(-1), throwsArgumentError);
      expect(() => service.drawQuestions(3), throwsArgumentError);
    });
  });

  group('recordAnswer 权重', () {
    test('答错翻倍、答对复位、有上限', () {
      final service = QuestionBankService();
      final groupId = service.createGroup('G').id;
      service.addQuestions(
        groupId,
        [BankQuestion(question: 'q', answer: 'a')],
      );
      final id = service.groupById(groupId)!.questions.single.id;

      expect(service.weightOf(id), 1);
      service.recordAnswer(id, correct: false);
      expect(service.weightOf(id), 2);
      service.recordAnswer(id, correct: true);
      expect(service.weightOf(id), 1);

      for (var i = 0; i < 10; i++) {
        service.recordAnswer(id, correct: false);
      }
      expect(service.weightOf(id), service.maxWeight);
    });

    test('答错的题明显更容易被抽中（固定随机种子）', () {
      final service = QuestionBankService(recentMemorySize: 0);
      final groupId = service.createGroup('G').id;
      service.addQuestions(groupId, buildQuestions('q', 6));
      final weakId = service.groupById(groupId)!.questions.first.id;
      for (var i = 0; i < 3; i++) {
        service.recordAnswer(weakId, correct: false);
      }
      // weakId 权重 8，其余各 1 → 期望占比 8/13 ≈ 62%。

      final rng = Random(2026);
      final counts = <String, int>{};
      for (var i = 0; i < 200; i++) {
        final id = service.drawQuestions(1, random: rng).single.id;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      final weakCount = counts[weakId]!;
      for (final entry in counts.entries) {
        if (entry.key == weakId) continue;
        expect(weakCount, greaterThan(entry.value * 3),
            reason: '加权题 ${entry.key} 被抽中 ${entry.value} 次，'
                '加权题仅 $weakCount 次，权重未生效');
      }
      expect(weakCount, greaterThan(200 ~/ 3));
    });
  });
}
