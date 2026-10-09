/// question_group 与 question 表的联合读写。
///
/// 提供 [QuestionBankService] 的持久化后端：分组与题目的增删改 + 答题计数。
library;

import 'package:sqflite/sqflite.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/question_group.dart';
import '../mappers.dart';

class QuestionRepository {
  final Database _db;
  final DateTime Function() _clock;

  QuestionRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 载入所有未软删的分组（按创建顺序）及其题目（含对错计数）。
  Future<List<QuestionGroup>> loadAll() async {
    final groupRows = await _db.query(
      'question_group',
      where: 'deleted = 0',
      orderBy: 'created_at ASC',
    );
    final result = <QuestionGroup>[];
    for (final gRow in groupRows) {
      final qRows = await _db.query(
        'question',
        where: 'group_id = ? AND deleted = 0',
        whereArgs: [gRow['id']],
        orderBy: 'created_at ASC',
      );
      final questions = qRows.map(questionFromRow).toList();
      result.add(groupFromRow(
        gRow,
        questions.map((e) => e.question).toList(),
      ));
    }
    return result;
  }

  /// 载入某道题的对错计数（供 service 初始化内存权重）。
  Future<({int correct, int wrong})> loadCounts(String questionId) async {
    final rows = await _db.query(
      'question',
      columns: ['correct_count', 'wrong_count'],
      where: 'id = ? AND deleted = 0',
      whereArgs: [questionId],
      limit: 1,
    );
    if (rows.isEmpty) return (correct: 0, wrong: 0);
    return (
      correct: rows.first['correct_count'] as int,
      wrong: rows.first['wrong_count'] as int,
    );
  }

  /// 载入全部题目计数（id -> (correct, wrong)），一次查询。
  Future<Map<String, ({int correct, int wrong})>> loadAllCounts() async {
    final rows = await _db.query(
      'question',
      columns: ['id', 'correct_count', 'wrong_count'],
      where: 'deleted = 0',
    );
    return {
      for (final r in rows)
        r['id'] as String: (
          correct: r['correct_count'] as int,
          wrong: r['wrong_count'] as int,
        ),
    };
  }

  // -- 分组 --------------------------------------------------

  Future<void> insertGroup(QuestionGroup g) async {
    final now = _clock();
    await _db.insert('question_group', groupToRow(g, now: now));
    for (final q in g.questions) {
      await _db.insert('question', questionToRow(q, groupId: g.id, now: now));
    }
  }

  Future<void> updateGroup(QuestionGroup g) async {
    final now = _clock();
    await _db.update(
      'question_group',
      {
        'name': g.name,
        'type': g.type,
        'enabled': g.enabled ? 1 : 0,
        'updated_at': toTimestamp(now),
      },
      where: 'id = ?',
      whereArgs: [g.id],
    );
  }

  /// 软删除分组及其全部题目。
  Future<void> softDeleteGroup(String groupId) async {
    final now = _clock();
    final ts = toTimestamp(now);
    await _db.transaction((txn) async {
      await txn.update(
        'question_group',
        {'deleted': 1, 'updated_at': ts},
        where: 'id = ?',
        whereArgs: [groupId],
      );
      await txn.update(
        'question',
        {'deleted': 1, 'updated_at': ts},
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    });
  }

  // -- 题目 --------------------------------------------------

  Future<void> insertQuestion(String groupId, BankQuestion q) async {
    await _db.insert(
      'question',
      questionToRow(q, groupId: groupId, now: _clock()),
    );
  }

  /// 批量插入题目（同一事务）。
  Future<void> insertQuestions(
      String groupId, List<BankQuestion> questions) async {
    if (questions.isEmpty) return;
    final now = _clock();
    final batch = _db.batch();
    for (final q in questions) {
      batch.insert('question', questionToRow(q, groupId: groupId, now: now));
    }
    await batch.commit();
  }

  /// 编辑题目（保持 id 不变，因此权重/记忆不受影响）。
  Future<void> updateQuestion(
    String questionId, {
    required String question,
    required String answer,
    String? hint,
  }) async {
    final trimmedHint = hint?.trim();
    await _db.update(
      'question',
      {
        'question': question.trim(),
        'answer': answer.trim(),
        'hint':
            (trimmedHint == null || trimmedHint.isEmpty) ? null : trimmedHint,
        'updated_at': toTimestamp(_clock()),
      },
      where: 'id = ?',
      whereArgs: [questionId],
    );
  }

  Future<void> softDeleteQuestions(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final ts = toTimestamp(_clock());
    await _db.update(
      'question',
      {'deleted': 1, 'updated_at': ts},
      where: 'id IN (${List.filled(list.length, '?').join(',')})',
      whereArgs: list,
    );
  }

  /// 记录一次作答：答对 correct+1，答错 wrong+1。
  Future<void> bumpCount(String questionId, {required bool correct}) async {
    final col = correct ? 'correct_count' : 'wrong_count';
    await _db.rawUpdate(
      'UPDATE question SET $col = $col + 1, updated_at = ? '
      'WHERE id = ? AND deleted = 0',
      [toTimestamp(_clock()), questionId],
    );
  }
}
