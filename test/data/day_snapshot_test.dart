/// day_snapshot 表：repo 读写 + V2→V3 迁移测试。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:screen_time_manager/data/database.dart';
import 'package:screen_time_manager/data/repositories/day_snapshot_repository.dart';
import 'package:screen_time_manager/data/schema.dart';
import 'package:screen_time_manager/models/day_snapshot.dart';
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
    // 以 kSchemaVersion=3 打开触发 onUpgrade。
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
}
