/// rest_session 表读写：只增不改，结束时 insert 完整行。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/rest_session.dart';
import '../mappers.dart';

class RestSessionRepository {
  final Database _db;
  final DateTime Function() _clock;

  RestSessionRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 插入一条已结束的休息会话。
  Future<void> insert(RestSession session) async {
    await _db.insert(
      'rest_session',
      restSessionToRow(session, now: _clock()),
    );
  }

  /// 按开始时间倒序分页查询。
  Future<List<RestSession>> listRecent({int limit = 50}) async {
    final rows = await _db.query(
      'rest_session',
      where: 'deleted = 0',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(restSessionFromRow).toList();
  }
}
