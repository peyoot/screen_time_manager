/// 测试用 DB 助手：每次打开一个全新的临时文件数据库，保证测试间隔离。
///
/// [openAppDatabase] 内部会按平台初始化 ffi；测试在 Linux 桌面运行时
/// 自动启用 `databaseFactoryFfi`。每个调用使用唯一临时目录，避免
/// `:memory:` 在 ffi 下被复用导致跨测试数据残留。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:screen_time_manager/data/database.dart';
import 'package:sqflite/sqflite.dart';

int _counter = 0;

/// 打开一个全新的临时文件数据库（每次调用均独立）。
Future<Database> openTestDb() async {
  final dir = await Directory.systemTemp.createTemp('stm_test_${_counter++}_');
  return openAppDatabase(dbPath: p.join(dir.path, 'test.db'));
}
