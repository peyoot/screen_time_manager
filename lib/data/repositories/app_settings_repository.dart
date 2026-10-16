/// app_settings 表的读写：单行（id=1）配置。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/app_settings.dart';
import '../mappers.dart';

class AppSettingsRepository {
  final Database _db;
  final DateTime Function() _clock;

  /// 写入门：串行化所有 upsert，防止并发写交错时旧快照覆盖新快照
  /// （与 QuestionBankService 的 _lastWrite 约定一致）。
  Future<void> _lastWrite = Future<void>.value();

  AppSettingsRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// 加载配置；表为空时插入 [AppSettings.defaults] 并返回。
  Future<AppSettings> loadOrInit() async {
    final rows = await _db.query(
      'app_settings',
      where: 'id = ? AND deleted = 0',
      whereArgs: [kAppSettingsRowId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await upsert(AppSettings.defaults);
      return AppSettings.defaults;
    }
    return appSettingsFromRow(rows.first);
  }

  /// 写入（或覆盖）配置为单行记录。每次调用刷新 updated_at。
  /// 通过写入门串行执行，返回的 Future 在实际落库后完成。
  Future<void> upsert(AppSettings settings) {
    final op = _lastWrite.then((_) => _upsertNow(settings));
    // 失败不阻塞后续写入（调用方普遍 fire-and-forget）。
    _lastWrite = op.catchError((_) {});
    return op;
  }

  /// 等待全部挂起的写入完成（测试断言 DB 前必须调用，
  /// 与 QuestionBankService.flush 约定一致）。
  Future<void> flush() => _lastWrite;

  /// 实际执行单行 upsert（仅由 [upsert] 经写入门调用）。
  Future<void> _upsertNow(AppSettings settings) async {
    final now = _clock();
    final existing = await _db.query(
      'app_settings',
      where: 'id = ?',
      whereArgs: [kAppSettingsRowId],
      limit: 1,
    );
    final row = appSettingsToRow(
      settings,
      now: now,
      createdAt: existing.isEmpty ? now : null,
    );
    if (existing.isEmpty) {
      // replace 兜底：并发两次 upsert 都判定"不存在"时，
      // 后写者覆盖先写者（单行配置本就语义为全量覆盖），
      // 避免主键冲突被调用方静默吞掉导致配置丢失。
      await _db.insert(
        'app_settings',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // 单行配置允许覆盖（设置以云端为准时不走本地更新路径）。
      await _db.update(
        'app_settings',
        row,
        where: 'id = ?',
        whereArgs: [kAppSettingsRowId],
      );
    }
  }
}
