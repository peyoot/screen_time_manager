import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/data/repositories/rest_session_repository.dart';
import 'package:screen_time_manager/data/repositories/screen_session_repository.dart';
import 'package:screen_time_manager/data/repositories/snooze_record_repository.dart';
import 'package:screen_time_manager/data/repositories/sync_queue_repository.dart';
import 'package:screen_time_manager/models/rest_session.dart';
import 'package:screen_time_manager/models/screen_session.dart';
import 'package:screen_time_manager/models/snooze_record.dart';

import '_helpers.dart';

void main() {
  group('ScreenSessionRepository', () {
    late ScreenSessionRepository repo;
    setUp(() async {
      repo = ScreenSessionRepository(await openTestDb());
    });

    test('insert 后 listRecent 能查到', () async {
      final now = DateTime.utc(2026, 10, 9, 8, 0);
      await repo.insert(ScreenSession(
        id: 's1',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 5)),
        exemptionCount: 1,
        quizCorrectCount: 2,
        quizWrongCount: 0,
      ));
      final list = await repo.listRecent();
      expect(list.length, 1);
      expect(list.first.id, 's1');
      expect(list.first.exemptionCount, 1);
      expect(list.first.quizCorrectCount, 2);
    });

    test('statsForDay 按自然日聚合豁免与答题统计', () async {
      final day = DateTime.utc(2026, 10, 9, 10, 0);
      await repo.insert(ScreenSession(
        id: 'a', startedAt: day, endedAt: day.add(Duration.zero),
        exemptionCount: 1, quizCorrectCount: 1, quizWrongCount: 0,
      ));
      await repo.insert(ScreenSession(
        id: 'b', startedAt: day.add(const Duration(hours: 2)),
        endedAt: day.add(const Duration(hours: 3)),
        exemptionCount: 0, quizCorrectCount: 0, quizWrongCount: 2,
      ));
      // 不同自然日不应计入。
      await repo.insert(ScreenSession(
        id: 'c', startedAt: day.add(const Duration(days: 1)),
        endedAt: day.add(const Duration(days: 1, hours: 1)),
        exemptionCount: 5, quizCorrectCount: 5, quizWrongCount: 5,
      ));
      final stats = await repo.statsForDay(day);
      expect(stats.sessions, 2);
      expect(stats.exemptions, 1);
      expect(stats.correct, 1);
      expect(stats.wrong, 2);
    });
  });

  group('RestSessionRepository', () {
    late RestSessionRepository repo;
    setUp(() async {
      repo = RestSessionRepository(await openTestDb());
    });

    test('自然结束 completed=true，提前结束 completed=false', () async {
      final start = DateTime.utc(2026, 10, 9, 9, 0);
      await repo.insert(RestSession(
        id: 'r1', startedAt: start,
        endedAt: start.add(const Duration(minutes: 10)),
        plannedDuration: const Duration(minutes: 10),
        actualDuration: const Duration(minutes: 10),
        completed: true,
      ));
      await repo.insert(RestSession(
        id: 'r2', startedAt: start,
        endedAt: start.add(const Duration(minutes: 2)),
        plannedDuration: const Duration(minutes: 10),
        actualDuration: const Duration(minutes: 2),
        completed: false,
      ));
      final list = await repo.listRecent();
      expect(list.length, 2);
      final byId = {for (final e in list) e.id: e};
      expect(byId['r1']!.completed, true);
      expect(byId['r2']!.completed, false);
    });
  });

  group('SnoozeRecordRepository', () {
    late SnoozeRecordRepository repo;
    setUp(() async {
      repo = SnoozeRecordRepository(await openTestDb());
    });

    test('insert 后 forScreenSession 查到关联记录', () async {
      await repo.insert(const SnoozeRecord(
        id: 'x1', screenSessionId: 's1', quizRound: 0,
        questionIdsJson: '["q1"]', passed: true,
        correctCount: 1, wrongCount: 0,
      ));
      await repo.insert(const SnoozeRecord(
        id: 'x2', screenSessionId: 's1', quizRound: 1,
        questionIdsJson: '["q2"]', passed: false,
        correctCount: 0, wrongCount: 1,
      ));
      await repo.insert(const SnoozeRecord(
        id: 'x3', screenSessionId: 's2', quizRound: 0,
        questionIdsJson: '["q3"]', passed: true,
      ));
      final forS1 = await repo.forScreenSession('s1');
      expect(forS1.length, 2);
      expect(forS1.every((e) => e.screenSessionId == 's1'), true);
    });
  });

  group('SyncQueueRepository', () {
    late SyncQueueRepository repo;
    setUp(() async {
      repo = SyncQueueRepository(await openTestDb());
    });

    test('enqueue 后 listPending 按序返回，markSynced 后不再返回', () async {
      await repo.enqueue(
        id: 'op1', tableName: 'question', recordId: 'q1',
        operation: 'insert', payload: {'q': '一'},
      );
      await repo.enqueue(
        id: 'op2', tableName: 'question', recordId: 'q2',
        operation: 'update', payload: {'q': '二'},
      );
      final pending = await repo.listPending();
      expect(pending.map((e) => e.id), ['op1', 'op2']);
      await repo.markSynced('op1');
      final after = await repo.listPending();
      expect(after.length, 1);
      expect(after.first.id, 'op2');
    });
  });
}
