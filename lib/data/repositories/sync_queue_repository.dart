/// sync_queue 表读写：离线操作队列。
///
/// 本阶段仅提供入队与查询接口，实际消费/上传留到同步引擎阶段。
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../mappers.dart';

/// 一次待同步的写操作。
class SyncQueueEntry {
  final String id;
  final String tableName;
  final String recordId;
  final String operation;
  final String? payload;
  final DateTime createdAt;
  final bool synced;

  const SyncQueueEntry({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.synced,
  });
}

class SyncQueueRepository {
  final Database _db;
  final DateTime Function() _clock;

  SyncQueueRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 追加一条待同步记录。
  Future<void> enqueue({
    required String id,
    required String tableName,
    required String recordId,
    required String operation,
    Object? payload,
  }) async {
    await _db.insert('sync_queue', {
      'id': id,
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': toTimestamp(_clock()),
      'synced': 0,
    });
  }

  /// 查询全部未同步条目（按入队顺序）。
  Future<List<SyncQueueEntry>> listPending({int limit = 100}) async {
    final rows = await _db.query(
      'sync_queue',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows
        .map((r) => SyncQueueEntry(
              id: r['id'] as String,
              tableName: r['table_name'] as String,
              recordId: r['record_id'] as String,
              operation: r['operation'] as String,
              payload: r['payload'] as String?,
              createdAt: fromTimestamp(r['created_at'] as String),
              synced: false,
            ))
        .toList();
  }

  /// 标记某条已同步。
  Future<void> markSynced(String id) async {
    await _db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
