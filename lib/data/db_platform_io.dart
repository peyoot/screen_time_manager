/// 原生平台（Android/iOS/Linux/macOS/Windows）的数据库工厂与路径解析。
///
/// 由 [database.dart] 在非 Web 编译时通过条件导入选中。
library;

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialized = false;

/// 初始化数据库工厂：桌面端用 ffi（sqflite 不自带桌面实现），
/// 移动端保留 sqflite 默认实现（MethodChannel + 系统 SQLite）。
Future<void> initDatabaseFactory() async {
  if (_initialized) return;
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  _initialized = true;
}

/// 原生平台 DB 文件位于应用文档目录。
Future<String> resolveDatabasePath(String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, fileName);
}
