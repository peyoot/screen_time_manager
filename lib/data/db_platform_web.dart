/// Web 平台的数据库工厂与路径解析。
///
/// 由 [database.dart] 在 Web 编译时（`dart.library.js_interop` 可用）
/// 通过条件导入选中。**此文件不得 import `dart:io`**——Web 运行时没有
/// `Platform` 类，任何引用都会抛 `Unsupported operation: Platform._operatingSystem`。
///
/// 前置条件：已执行 `dart run sqflite_common_ffi_web:setup`，
/// 将 `sqflite_sw.js` 与 SQLite WASM 产物放入 `web/` 目录。
library;

import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

bool _initialized = false;

/// 初始化 Web 数据库工厂：基于 SQLite WASM + Shared Worker，
/// 首次打开 DB 时惰性加载 `sqflite_sw.js`（数据持久化在 OPFS）。
Future<void> initDatabaseFactory() async {
  if (_initialized) return;
  databaseFactory = databaseFactoryFfiWeb;
  _initialized = true;
}

/// Web 端路径是虚拟文件名（由 worker 内的文件系统管理），
/// 不需要 path_provider，直接返回文件名即可。
Future<String> resolveDatabasePath(String fileName) async => fileName;
