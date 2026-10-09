/// 数据库连接管理：打开、建表、版本迁移。
///
/// - 移动端（Android/iOS/HarmonyOS）使用 `sqflite` 默认实现，
///   DB 文件位于应用文档目录 `screen_time_manager.db`；
/// - 桌面端（Linux）与单元测试通过 `sqflite_common_ffi` 初始化，
///   测试中可注入 in-memory DB 路径。
library;

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';

/// 数据库文件名。
const String kDbFileName = 'screen_time_manager.db';

/// 全局标记：是否已为桌面/测试初始化 ffi。
bool _ffiInitialized = false;

/// 确保桌面平台使用 ffi 实现。
///
/// 在 Linux/macOS/Windows 桌面运行时必须调用一次；
/// 移动端走 sqflite 默认实现，无需调用。测试中也可手动调用以启用 in-memory DB。
void ensureFfiInitialized() {
  if (_ffiInitialized) return;
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  _ffiInitialized = true;
}

/// 打开（或创建）应用数据库。
///
/// [dbPath] 用于测试注入 in-memory 路径（`":memory:"`）；
/// 生产环境留空，将自动定位应用文档目录。
Future<Database> openAppDatabase({String? dbPath}) async {
  ensureFfiInitialized();
  final path = dbPath ?? await _resolveDbPath();
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

/// 解析生产环境的 DB 文件路径（应用文档目录 + 文件名）。
Future<String> _resolveDbPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, kDbFileName);
}
