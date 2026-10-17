/// 数据库 schema 定义与版本迁移。
///
/// 时间戳统一存 ISO-8601 TEXT（UTC，字典序可排序）；
/// 时长存 INTEGER 秒；UUID 存 TEXT；布尔/标志位存 INTEGER（0/1）。
library;

import 'package:sqflite/sqflite.dart';

/// 当前 schema 版本号。
const int kSchemaVersion = 3;

/// V1 建表语句：按外键依赖顺序排列。
const List<String> kSchemaV1Statements = [
  // app_settings：单行记录（id=1），列名沿用 AppSettings 模型字段名。
  '''
  CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY,
    quiz_interval_seconds INTEGER NOT NULL,
    questions_per_quiz INTEGER NOT NULL,
    required_correct_count INTEGER NOT NULL,
    rest_duration_seconds INTEGER NOT NULL,
    daily_exemption_limit INTEGER NOT NULL DEFAULT 2,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  )
  ''',
  // question_group：题库分组，支持 enabled 开关与软删除。
  '''
  CREATE TABLE question_group (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'input',
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  )
  ''',
  // question：题目，含 correct_count/wrong_count 用于加权抽题。
  '''
  CREATE TABLE question (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    hint TEXT,
    correct_count INTEGER NOT NULL DEFAULT 0,
    wrong_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (group_id) REFERENCES question_group(id)
  )
  ''',
  // screen_session：亮屏会话，只增不改，结束时一次性 insert 完整行。
  '''
  CREATE TABLE screen_session (
    id TEXT PRIMARY KEY,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    exemption_count INTEGER NOT NULL DEFAULT 0,
    quiz_correct_count INTEGER NOT NULL DEFAULT 0,
    quiz_wrong_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  )
  ''',
  // rest_session：休息会话，结束时 insert 完整行。
  '''
  CREATE TABLE rest_session (
    id TEXT PRIMARY KEY,
    started_at TEXT NOT NULL,
    ended_at TEXT NOT NULL,
    planned_duration_seconds INTEGER NOT NULL,
    actual_duration_seconds INTEGER NOT NULL,
    completed INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  )
  ''',
  // snooze_record：豁免明细，关联 screen_session，记录本次抽到的题目。
  '''
  CREATE TABLE snooze_record (
    id TEXT PRIMARY KEY,
    screen_session_id TEXT,
    quiz_round INTEGER NOT NULL,
    question_ids TEXT NOT NULL,
    passed INTEGER NOT NULL,
    correct_count INTEGER NOT NULL DEFAULT 0,
    wrong_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  )
  ''',
  // sync_queue：离线操作队列，网络恢复后按顺序上传。
  '''
  CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    payload TEXT,
    created_at TEXT NOT NULL,
    synced INTEGER NOT NULL DEFAULT 0
  )
  ''',
];

/// 索引语句：加速常用查询。
const List<String> kSchemaV1Indexes = [
  'CREATE INDEX idx_question_group_id ON question(group_id) WHERE deleted = 0',
  'CREATE INDEX idx_screen_session_started ON screen_session(started_at) WHERE deleted = 0',
  'CREATE INDEX idx_rest_session_started ON rest_session(started_at) WHERE deleted = 0',
  'CREATE INDEX idx_snooze_record_screen ON snooze_record(screen_session_id) WHERE deleted = 0',
  'CREATE INDEX idx_sync_queue_synced ON sync_queue(synced) WHERE synced = 0',
];

/// 在指定数据库上执行 V1 建表（建表 + 索引）。
Future<void> applySchemaV1(Database db) async {
  final batch = db.batch();
  for (final stmt in kSchemaV1Statements) {
    batch.execute(stmt);
  }
  for (final idx in kSchemaV1Indexes) {
    batch.execute(idx);
  }
  await batch.commit();
}

/// V2 迁移：app_settings 增加 `admin_password_hash`（本机管理密码哈希，
/// null 表示未设置）。V1 DDL 保持原样，升级与新建都经此语句补齐。
const List<String> kSchemaV2Statements = [
  'ALTER TABLE app_settings ADD COLUMN admin_password_hash TEXT',
];

/// 在指定数据库上执行 V2 迁移。
Future<void> applySchemaV2(Database db) async {
  final batch = db.batch();
  for (final stmt in kSchemaV2Statements) {
    batch.execute(stmt);
  }
  await batch.commit();
}

/// V3 迁移：新增 `day_snapshot` 表——当日运行状态快照（每天一行）。
///
/// 进程被杀（划掉应用/系统回收）重启后据此恢复当日进度：
/// 累计亮屏、阈值进度、已用豁免、当日休息统计与进行中休息的截止时刻。
/// 控制器运行期按约 5 秒节流 upsert 当天行。
const List<String> kSchemaV3Statements = [
  '''
  CREATE TABLE day_snapshot (
    day TEXT PRIMARY KEY,
    screen_seconds INTEGER NOT NULL DEFAULT 0,
    threshold_seconds INTEGER NOT NULL DEFAULT 0,
    exemptions_used_today INTEGER NOT NULL DEFAULT 0,
    rest_count INTEGER NOT NULL DEFAULT 0,
    rest_seconds INTEGER NOT NULL DEFAULT 0,
    rest_exemptions INTEGER NOT NULL DEFAULT 0,
    rest_ends_at TEXT,
    updated_at TEXT NOT NULL
  )
  ''',
];

/// 在指定数据库上执行 V3 迁移。
Future<void> applySchemaV3(Database db) async {
  final batch = db.batch();
  for (final stmt in kSchemaV3Statements) {
    batch.execute(stmt);
  }
  await batch.commit();
}
