import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/data/repositories/question_repository.dart';
import 'package:screen_time_manager/question_bank/bank_question.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';

import '_helpers.dart';

void main() {
  late QuestionRepository repo;
  late QuestionBankService service;

  setUp(() async {
    repo = QuestionRepository(await openTestDb());
    service = QuestionBankService(repository: repo);
  });

  test('create → reload 后分组与题目一致', () async {
    service.importIntoNewGroup(
      name: '组A',
      questions: [
        BankQuestion(question: '题1', answer: '答1'),
        BankQuestion(question: '题2', answer: '答2', hint: '提示'),
      ],
    );
    await service.flush();

    final reloaded = QuestionBankService(repository: repo);
    await reloaded.loadFromDb();
    expect(reloaded.groups.length, 1);
    expect(reloaded.groups.first.name, '组A');
    expect(reloaded.groups.first.questions.length, 2);
    expect(reloaded.groups.first.questions.first.question, '题1');
    expect(reloaded.groups.first.questions.last.hint, '提示');
  });

  test('updateQuestion 持久化到 DB（reload 后看到新文本）', () async {
    final g = service.importIntoNewGroup(
      name: '组B',
      questions: [BankQuestion(question: '旧', answer: '旧答')],
    );
    service.updateQuestion(g.id, g.questions.first.id,
        question: '新题', answer: '新答', hint: '新提示');
    await service.flush();

    final reloaded = QuestionBankService(repository: repo);
    await reloaded.loadFromDb();
    final q = reloaded.groups.first.questions.first;
    expect(q.question, '新题');
    expect(q.answer, '新答');
    expect(q.hint, '新提示');
  });

  test('recordAnswer 答错后 wrong_count 落库', () async {
    final g = service.importIntoNewGroup(
      name: '组C',
      questions: [BankQuestion(id: 'wq1', question: '题', answer: '答')],
    );
    service.recordAnswer(g.questions.first.id, correct: false);
    service.recordAnswer(g.questions.first.id, correct: false);
    service.recordAnswer(g.questions.first.id, correct: true);
    await service.flush();

    final counts = await repo.loadAllCounts();
    expect(counts['wq1']!.wrong, 2);
    expect(counts['wq1']!.correct, 1);
  });

  test('reload 后按 wrong_count 推导内存权重', () async {
    // 答错 3 次（maxWeight=8 → 权重应为 8）。
    final g = service.importIntoNewGroup(
      name: '组D',
      questions: [BankQuestion(id: 'wq2', question: '题', answer: '答')],
    );
    for (var i = 0; i < 3; i++) {
      service.recordAnswer(g.questions.first.id, correct: false);
    }
    await service.flush();

    final reloaded = QuestionBankService(repository: repo, maxWeight: 8);
    await reloaded.loadFromDb();
    expect(reloaded.weightOf('wq2'), 8);
  });
}
