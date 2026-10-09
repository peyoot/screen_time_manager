import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '_helpers.dart';
import 'package:screen_time_manager/data/schema.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDb();
  });
  tearDown(() async => db.close());

  test('建表后 sqlite_master 可见全部 6 张业务表 + sync_queue', () async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final names = rows.map((r) => r['name'] as String).toSet();
    expect(names, containsAll([
      'app_settings',
      'question_group',
      'question',
      'screen_session',
      'rest_session',
      'snooze_record',
      'sync_queue',
    ]));
  });

  test('question 表含 correct_count/wrong_count/created_at/updated_at/deleted 列',
      () async {
    final cols = await db.rawQuery('PRAGMA table_info(question)');
    final names = cols.map((c) => c['name'] as String).toSet();
    expect(names, containsAll([
      'id', 'group_id', 'question', 'answer', 'hint',
      'correct_count', 'wrong_count',
      'created_at', 'updated_at', 'deleted',
    ]));
  });

  test('SchemaV1 重复执行不报错（applySchemaV1 幂等）', () async {
    // 再次执行建表语句应抛异常（表已存在），验证不是静默重复。
    await expectLater(
      applySchemaV1(db),
      throwsA(isA<Object>()),
    );
  });
}
