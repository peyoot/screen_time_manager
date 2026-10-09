/// 数据库连接管理：打开、建表、版本迁移。
///
/// 平台差异通过条件导入隔离：
/// - 原生（`dart:io` 可用）→ [db_platform_io.dart]：桌面用 `sqflite_common_ffi`，
///   移动端用 sqflite 默认实现，DB 文件在应用文档目录；
/// - Web（`dart.library.js_interop` 可用）→ [db_platform_web.dart]：
///   用 `sqflite_common_ffi_web`（SQLite WASM + Shared Worker）。
///
/// 测试通过 [openAppDatabase] 的 `dbPath` 参数注入临时文件 DB。
library;

import 'package:sqflite/sqflite.dart';

import 'db_platform_io.dart'
    if (dart.library.js_interop) 'db_platform_web.dart' as platform;
import 'schema.dart';

/// 数据库文件名。
const String kDbFileName = 'screen_time_manager.db';

/// 打开（或创建）应用数据库。
///
/// [dbPath] 用于测试注入自定义路径；生产环境留空，按平台自动定位
/// （原生：应用文档目录；Web：OPFS 中的虚拟文件名）。
Future<Database> openAppDatabase({String? dbPath}) async {
  await platform.initDatabaseFactory();
  final path = dbPath ?? await platform.resolveDatabasePath(kDbFileName);
  return openDatabase(
    path,
    version: kSchemaVersion,
    onCreate: (db, _) => applySchemaV1(db),
    onUpgrade: (db, oldVersion, newVersion) async {
      // 后续版本在此追加阶梯式迁移；V1 首版无需处理。
      if (oldVersion < kSchemaVersion) {
        await applySchemaV1(db);
      }
    },
  );
}
