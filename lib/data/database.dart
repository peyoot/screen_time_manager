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
const String kDbFileName = 'screen_tempo.db';

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
    onCreate: (db, _) async {
      // 新建库依次应用全部版本阶梯，V1 DDL 保持历史原样。
      await applySchemaV1(db);
      await applySchemaV2(db);
      await applySchemaV3(db);
      await applySchemaV4(db);
      await applySchemaV5(db);
      await applySchemaV6(db);
      await applySchemaV7(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      // 阶梯式迁移：每个版本只补自己的增量语句。
      if (oldVersion < 2) {
        await applySchemaV2(db);
      }
      if (oldVersion < 3) {
        await applySchemaV3(db);
      }
      if (oldVersion < 4) {
        await applySchemaV4(db);
      }
      if (oldVersion < 5) {
        await applySchemaV5(db);
      }
      if (oldVersion < 6) {
        await applySchemaV6(db);
      }
      if (oldVersion < 7) {
        await applySchemaV7(db);
      }
    },
  );
}
