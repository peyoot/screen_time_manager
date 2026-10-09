/// screen_session 表读写：只增不改，结束时一次性 insert 完整行。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/screen_session.dart';
import '../mappers.dart';

class ScreenSessionRepository {
  final Database _db;
  final DateTime Function() _clock;

  ScreenSessionRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 插入一条已结束的亮屏会话。
  Future<void> insert(ScreenSession session) async {
    await _db.insert(
      'screen_session',
      screenSessionToRow(session, now: _clock()),
    );
  }

  /// 按开始时间倒序分页查询。
  Future<List<ScreenSession>> listRecent({int limit = 50}) async {
    final rows = await _db.query(
      'screen_session',
      where: 'deleted = 0',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(screenSessionFromRow).toList();
  }

  /// 按某自然日统计豁免次数与答题对错（供每日聚合预览）。
  Future<({int sessions, int exemptions, int correct, int wrong})>
      statsForDay(DateTime day) async {
    // 以 started_at 的日期前缀匹配 yyyy-MM-dd。
    final prefix = _dayPrefix(day);
    final rows = await _db.rawQuery(
      'SELECT '
      'COUNT(*) AS sessions, '
      'COALESCE(SUM(exemption_count), 0) AS exemptions, '
      'COALESCE(SUM(quiz_correct_count), 0) AS correct, '
      'COALESCE(SUM(quiz_wrong_count), 0) AS wrong '
      'FROM screen_session '
      'WHERE deleted = 0 AND date(started_at) = ?',
      [prefix],
    );
    final r = rows.first;
    return (
      sessions: r['sessions'] as int,
      exemptions: r['exemptions'] as int,
      correct: r['correct'] as int,
      wrong: r['wrong'] as int,
    );
  }

  String _dayPrefix(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
