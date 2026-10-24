/// day_snapshot 表：repo 读写 + V2→V3 / V3→V4 / V5→V6 迁移测试。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:screen_time_manager/data/database.dart';
import 'package:screen_time_manager/data/repositories/app_settings_repository.dart';
import 'package:screen_time_manager/data/repositories/day_snapshot_repository.dart';
import 'package:screen_time_manager/data/schema.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/day_snapshot.dart';
import 'package:screen_time_manager/models/exemption_window.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '_helpers.dart';

DaySnapshot buildSnapshot(DateTime day) {
  return DaySnapshot(
    day: day,
    screenTime: const Duration(minutes: 20),
    thresholdProgress: const Duration(minutes: 10),
    exemptionsUsedToday: 1,
    restCount: 2,
    restElapsed: const Duration(minutes: 5),
    restExemptions: 1,
    restEndsAt: day.add(const Duration(minutes: 30)),
  );
}

void main() {
  sqfliteFfiInit();

  test('upsert 后可按日读回全部字段', () async {
    final db = await openTestDb();
    final repo = DaySnapshotRepository(db);
    final day = DateTime(2026, 10, 17, 9, 30);
    final snapshot = buildSnapshot(day);

    await repo.upsert(snapshot);
    await repo.flush();

    final loaded = await repo.loadForDay(day);
    expect(loaded, isNotNull);
    expect(loaded!.dayKey, DaySnapshot.keyFor(day));
    expect(loaded.screenTime, snapshot.screenTime);
    expect(loaded.thresholdProgress, snapshot.thresholdProgress);
    expect(loaded.exemptionsUsedToday, snapshot.exemptionsUsedToday);
    expect(loaded.restCount, snapshot.restCount);
    expect(loaded.restElapsed, snapshot.restElapsed);
    expect(loaded.restExemptions, snapshot.restExemptions);
    // UTC 序列化往返后时刻相等（比较 epoch 值）。
    expect(
      loaded.restEndsAt!.millisecondsSinceEpoch,
      snapshot.restEndsAt!.millisecondsSinceEpoch,
    );
  });

  test('同日重复 upsert 为覆盖，不同日各占一行', () async {
    final db = await openTestDb();
    final repo = DaySnapshotRepository(db);
    final day = DateTime(2026, 10, 17);

    await repo.upsert(DaySnapshot(day: day, screenTime: const Duration(minutes: 1)));
    await repo.flush();
    await repo.upsert(DaySnapshot(day: day, screenTime: const Duration(minutes: 2)));
    await repo.flush();
    await repo.upsert(DaySnapshot(day: day.add(const Duration(days: 1))));
    await repo.flush();

    expect((await repo.loadForDay(day))!.screenTime, const Duration(minutes: 2));
    expect(
      (await repo.loadForDay(day.add(const Duration(days: 1))))!.screenTime,
      Duration.zero,
    );
    expect((await db.query('day_snapshot')).length, 2);
  });

  test('V2 旧库打开后自动迁移出 day_snapshot 表', () async {
    // 手工构造 V2 结构（V1 建表 + V2 增列）的旧库，再经 openAppDatabase
    // 以当前 kSchemaVersion 打开触发 onUpgrade。
    final dir = await Directory.systemTemp.createTemp('stm_v2_');
    final oldPath = p.join(dir.path, 'old.db');
    final old = await openDatabase(
      oldPath,
      version: 2,
      onCreate: (db, _) async {
        await applySchemaV1(db);
        await applySchemaV2(db);
      },
    );
    await old.close();

    final upgraded = await openAppDatabase(dbPath: oldPath);
    final repo = DaySnapshotRepository(upgraded);
    final day = DateTime(2026, 10, 17);
    await repo.upsert(buildSnapshot(day));
    await repo.flush();

    final loaded = await repo.loadForDay(day);
    expect(loaded, isNotNull);
    expect(loaded!.screenTime, const Duration(minutes: 20));
    expect(loaded.restEndsAt, isNotNull);
  });

  test('V3 旧库打开后自动迁移出 rest_timer_refresh_ms 列', () async {
    // 手工构造 V3 结构的旧库（含一行 app_settings），经 openAppDatabase
    // 升级到 V4 后新增列应带默认值 16。
    final dir = await Directory.systemTemp.createTemp('stm_v3_');
    final oldPath = p.join(dir.path, 'old.db');
    final old = await openDatabase(
      oldPath,
      version: 3,
      onCreate: (db, _) async {
        await applySchemaV1(db);
        await applySchemaV2(db);
        await applySchemaV3(db);
        await db.insert('app_settings', {
          'id': 1,
          'quiz_interval_seconds': 900,
          'questions_per_quiz': 1,
          'required_correct_count': 1,
          'rest_duration_seconds': 600,
          'daily_exemption_limit': 2,
          'created_at': '2026-10-17T00:00:00.000Z',
          'updated_at': '2026-10-17T00:00:00.000Z',
          'deleted': 0,
        });
      },
    );
    await old.close();

    final upgraded = await openAppDatabase(dbPath: oldPath);
    // 迁移列存在且默认 16。
    final rows = await upgraded.query('app_settings');
    expect(rows.single['rest_timer_refresh_ms'], 16);
    // repo 读取映射为默认值；自定义值可正常往返。
    final repo = AppSettingsRepository(upgraded);
    final loaded = await repo.loadOrInit();
    expect(loaded.restTimerRefreshMs, 16);
    await repo.upsert(
      AppSettings.defaults.copyWith(restTimerRefreshMs: 250),
    );
    await repo.flush();
    expect((await repo.loadOrInit()).restTimerRefreshMs, 250);
  });

  test('V4 旧库打开后自动迁移出 rest_enabled 列', () async {
    // 手工构造 V4 结构的旧库（含一行 app_settings），经 openAppDatabase
    // 升级到 V5 后新增列应带默认值 1（启用）。
    final dir = await Directory.systemTemp.createTemp('stm_v4_');
    final oldPath = p.join(dir.path, 'old.db');
    final old = await openDatabase(
      oldPath,
      version: 4,
      onCreate: (db, _) async {
        await applySchemaV1(db);
        await applySchemaV2(db);
        await applySchemaV3(db);
        await applySchemaV4(db);
        await db.insert('app_settings', {
          'id': 1,
          'quiz_interval_seconds': 900,
          'questions_per_quiz': 1,
          'required_correct_count': 1,
          'rest_duration_seconds': 600,
          'daily_exemption_limit': 2,
          'rest_timer_refresh_ms': 33,
          'created_at': '2026-10-17T00:00:00.000Z',
          'updated_at': '2026-10-17T00:00:00.000Z',
          'deleted': 0,
        });
      },
    );
    await old.close();

    final upgraded = await openAppDatabase(dbPath: oldPath);
    // 迁移列存在且默认 1（启用），既有 rest_timer_refresh_ms 值保留。
    final rows = await upgraded.query('app_settings');
    expect(rows.single['rest_enabled'], 1);
    expect(rows.single['rest_timer_refresh_ms'], 33);
    // repo 读取映射为默认启用；关闭开关可正常往返。
    final repo = AppSettingsRepository(upgraded);
    final loaded = await repo.loadOrInit();
    expect(loaded.restEnabled, isTrue);
    await repo.upsert(
      AppSettings.defaults.copyWith(restEnabled: false),
    );
    await repo.flush();
    expect((await repo.loadOrInit()).restEnabled, isFalse);
  });

  test('V5 旧库打开后自动迁移出 exemption_windows 列', () async {
    // 手工构造 V5 结构的旧库（含一行 app_settings），经 openAppDatabase
    // 升级到 V6 后新增列默认 '[]'（无豁免时间段），写入后可正常往返。
    final dir = await Directory.systemTemp.createTemp('stm_v5_');
    final oldPath = p.join(dir.path, 'old.db');
    final old = await openDatabase(
      oldPath,
      version: 5,
      onCreate: (db, _) async {
        await applySchemaV1(db);
        await applySchemaV2(db);
        await applySchemaV3(db);
        await applySchemaV4(db);
        await applySchemaV5(db);
        await db.insert('app_settings', {
          'id': 1,
          'quiz_interval_seconds': 900,
          'questions_per_quiz': 1,
          'required_correct_count': 1,
          'rest_duration_seconds': 600,
          'daily_exemption_limit': 2,
          'created_at': '2026-10-17T00:00:00.000Z',
          'updated_at': '2026-10-17T00:00:00.000Z',
          'deleted': 0,
        });
      },
    );
    await old.close();

    final upgraded = await openAppDatabase(dbPath: oldPath);
    final rows = await upgraded.query('app_settings');
    expect(rows.single['exemption_windows'], '[]');

    final repo = AppSettingsRepository(upgraded);
    expect((await repo.loadOrInit()).exemptionWindows, isEmpty);

    final window = ExemptionWindow(
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      weekdays: {DateTime.monday, DateTime.wednesday},
    );
    await repo.upsert(
      AppSettings.defaults.copyWith(exemptionWindows: [window]),
    );
    await repo.flush();
    expect((await repo.loadOrInit()).exemptionWindows, [window]);
  });
}
