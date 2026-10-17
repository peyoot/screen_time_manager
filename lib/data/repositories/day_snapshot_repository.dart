/// day_snapshot 表的读写：每日一行的运行状态快照。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/day_snapshot.dart';
import '../mappers.dart';

class DaySnapshotRepository {
  final Database _db;
  final DateTime Function() _clock;

  /// 写入门：串行化所有 upsert，防止并发写交错时旧快照覆盖新快照
  /// （与 AppSettingsRepository/QuestionBankService 的 _lastWrite 约定一致）。
  Future<void> _lastWrite = Future<void>.value();

  DaySnapshotRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 读取 [day] 所在自然日的快照；无快照（当天尚未写入/跨天）返回 null。
  Future<DaySnapshot?> loadForDay(DateTime day) async {
    final rows = await _db.query(
      'day_snapshot',
      where: 'day = ?',
      whereArgs: [DaySnapshot.keyFor(day)],
      limit: 1,
    );
    return rows.isEmpty ? null : daySnapshotFromRow(rows.first);
  }

  /// 写入（或覆盖）当日快照。通过写入门串行执行，
  /// 返回的 Future 在实际落库后完成。
  Future<void> upsert(DaySnapshot snapshot) {
    final op = _lastWrite.then((_) => _upsertNow(snapshot));
    // 失败不阻塞后续写入（调用方普遍 fire-and-forget）。
    _lastWrite = op.catchError((_) {});
    return op;
  }

  /// 等待全部挂起的写入完成（测试断言 DB 前必须调用）。
  Future<void> flush() => _lastWrite;

  Future<void> _upsertNow(DaySnapshot snapshot) async {
    // 每天一行、语义为全量覆盖，直接 replace。
    await _db.insert(
      'day_snapshot',
      daySnapshotToRow(snapshot, now: _clock()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
