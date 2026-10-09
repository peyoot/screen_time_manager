/// app_settings 表的读写：单行（id=1）配置。
library;

import 'package:sqflite/sqflite.dart';

import '../../models/app_settings.dart';
import '../mappers.dart';

class AppSettingsRepository {
  final Database _db;
  final DateTime Function() _clock;

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
  Future<void> upsert(AppSettings settings) async {
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
      await _db.insert('app_settings', row);
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
