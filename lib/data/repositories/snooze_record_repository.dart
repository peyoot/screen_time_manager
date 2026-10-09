/// snooze_record 表读写：每完成一轮答题豁免 insert 一行。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/snooze_record.dart';
import '../mappers.dart';

class SnoozeRecordRepository {
  final Database _db;
  final DateTime Function() _clock;

  SnoozeRecordRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 插入一条豁免明细记录。
  Future<void> insert(SnoozeRecord record) async {
    await _db.insert(
      'snooze_record',
      snoozeRecordToRow(record, now: _clock()),
    );
  }

  /// 查询某亮屏会话关联的全部豁免明细。
  Future<List<SnoozeRecord>> forScreenSession(String screenSessionId) async {
    final rows = await _db.query(
      'snooze_record',
      where: 'screen_session_id = ? AND deleted = 0',
      whereArgs: [screenSessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(snoozeRecordFromRow).toList();
  }

  /// 按创建时间倒序分页查询全部豁免明细。
  Future<List<SnoozeRecord>> listRecent({int limit = 50}) async {
    final rows = await _db.query(
      'snooze_record',
      where: 'deleted = 0',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(snoozeRecordFromRow).toList();
  }
}
