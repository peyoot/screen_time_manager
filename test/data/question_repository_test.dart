import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/data/repositories/question_repository.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_group.dart';

import '_helpers.dart';

void main() {
  late QuestionRepository repo;

  setUp(() async {
    final db = await openTestDb();
    repo = QuestionRepository(db);
  });

  QuestionGroup buildGroup(String id, String name) => QuestionGroup(
        id: id,
        name: name,
        questions: [
          BankQuestion(id: 'q1', question: '一加一等于几', answer: '2', hint: '基础加法'),
          BankQuestion(id: 'q2', question: '二加二等于几', answer: '4'),
        ],
      );

  test('insertGroup 后 loadAll 返回一致的分组与题目', () async {
    final g = buildGroup('g1', '数学');
    await repo.insertGroup(g);
    final loaded = await repo.loadAll();
    expect(loaded.length, 1);
    expect(loaded.first.id, 'g1');
    expect(loaded.first.name, '数学');
    expect(loaded.first.questions.length, 2);
    expect(loaded.first.questions.first.id, 'q1');
    expect(loaded.first.questions.first.hint, '基础加法');
  });

  test('updateGroup 修改名称与启停状态后持久化', () async {
    final g = buildGroup('g2', '原');
    await repo.insertGroup(g);
    await repo.updateGroup(g.copyWith(name: '新', enabled: false));
    final loaded = (await repo.loadAll()).first;
    expect(loaded.name, '新');
    expect(loaded.enabled, false);
  });

  test('softDeleteGroup 后分组与题目均不在 loadAll 中', () async {
    await repo.insertGroup(buildGroup('g3', '删除'));
    await repo.softDeleteGroup('g3');
    expect((await repo.loadAll()), isEmpty);
  });

  test('insertQuestions 批量追加题目', () async {
    final g = QuestionGroup(id: 'g4', name: '组', questions: const []);
    await repo.insertGroup(g);
    await repo.insertQuestions('g4', [
      BankQuestion(id: 'a', question: 'Q1', answer: 'A1'),
      BankQuestion(id: 'b', question: 'Q2', answer: 'A2'),
    ]);
    final loaded = (await repo.loadAll()).first;
    expect(loaded.questions.length, 2);
  });

  test('updateQuestion 保持 id 不变并修改文本', () async {
    final g = buildGroup('g5', '组');
    await repo.insertGroup(g);
    await repo.updateQuestion('q1',
        question: '新题干', answer: '新答案', hint: '提示');
    final loaded = (await repo.loadAll()).first;
    final q = loaded.questions.firstWhere((e) => e.id == 'q1');
    expect(q.question, '新题干');
    expect(q.answer, '新答案');
    expect(q.hint, '提示');
  });

  test('bumpCount 答对/答错累计到 correct_count/wrong_count', () async {
    final g = buildGroup('g6', '组');
    await repo.insertGroup(g);
    await repo.bumpCount('q1', correct: true);
    await repo.bumpCount('q1', correct: true);
    await repo.bumpCount('q1', correct: false);
    final counts = await repo.loadAllCounts();
    expect(counts['q1']!.correct, 2);
    expect(counts['q1']!.wrong, 1);
  });

  test('loadAllCounts 返回全部题目的累计计数', () async {
    await repo.insertGroup(buildGroup('g7', '组'));
    final counts = await repo.loadAllCounts();
    expect(counts.length, 2);
    expect(counts['q1']!.correct, 0);
    expect(counts['q2']!.wrong, 0);
  });
}
