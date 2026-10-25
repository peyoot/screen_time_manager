/// 管理密码：设置/校验/清除、DB 持久化与 V1→V2 迁移。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:screen_tempo/data/database.dart';
import 'package:screen_tempo/data/repositories/app_settings_repository.dart';
import 'package:screen_tempo/data/schema.dart';
import 'package:screen_tempo/models/app_settings.dart';
import 'package:screen_tempo/models/exemption_window.dart';
import 'package:screen_tempo/question_bank/question_bank_service.dart';
import 'package:screen_tempo/state_machine/screen_time_machine.dart';
import 'package:screen_tempo/ui/screen_time/screen_time_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/_helpers.dart';

ScreenTimeController _buildController({AppSettingsRepository? repo}) {
  final machine = ScreenTimeMachine(
    settings: AppSettings.defaults,
    initiallyScreenOn: true,
  );
  return ScreenTimeController(
    machine: machine,
    bankService: QuestionBankService(),
    questionsPerQuiz: 1,
    appSettingsRepo: repo,
    autoStart: false,
  );
}

void main() {
  test('未设置密码：hasAdminPassword=false，verify 恒 false', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    expect(controller.hasAdminPassword, isFalse);
    expect(controller.verifyAdminPassword('1234'), isFalse);
  });

  test('设置密码后可校验；错误密码不通过；清除后恢复无密码', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    controller.updateAdminPassword('1234');
    expect(controller.hasAdminPassword, isTrue);
    expect(controller.verifyAdminPassword('1234'), isTrue);
    expect(controller.verifyAdminPassword('0000'), isFalse);
    // 不落明文：只存加盐哈希。
    expect(controller.machine.settings.adminPasswordHash, isNot('1234'));
    controller.updateAdminPassword(null);
    expect(controller.hasAdminPassword, isFalse);
  });

  test('密码哈希经 repo 持久化；updateTiming 全行写入不丢密码', () async {
    final db = await openTestDb();
    final repo = AppSettingsRepository(db);
    await repo.loadOrInit();
    final controller = _buildController(repo: repo);
    addTearDown(controller.dispose);

    controller.updateAdminPassword('abcd');
    // updateTiming 用整行覆盖写入，密码列必须保留。
    controller.updateTiming(quizMinutes: 20, restMinutes: 5);
    // 控制器的 upsert 为 fire-and-forget，经写入门串行落库；
    // 断言前必须等待全部挂起写入完成。
    await repo.flush();

    final reloaded = await repo.loadOrInit();
    expect(
      reloaded.adminPasswordHash,
      controller.machine.settings.adminPasswordHash,
    );
    expect(reloaded.quizInterval, const Duration(minutes: 20));
  });

  test('updateTiming 写入豁免时间段并持久化；控制器暴露当前豁免状态', () async {
    final db = await openTestDb();
    final repo = AppSettingsRepository(db);
    await repo.loadOrInit();
    final controller = _buildController(repo: repo);
    addTearDown(controller.dispose);

    // 全天 + 每天重复：任意时刻都处于豁免时间段，判定不依赖当前时钟。
    final window = ExemptionWindow(
      startMinute: 0,
      endMinute: 1440,
      weekdays: {for (var d = 1; d <= 7; d++) d},
    );
    controller.updateTiming(
      quizMinutes: 20,
      restMinutes: 5,
      exemptionWindows: [window],
    );
    await repo.flush();

    final reloaded = await repo.loadOrInit();
    expect(reloaded.exemptionWindows, [window]);
    expect(controller.isRestExemptNow, isTrue);
    expect(controller.restActiveNow, isFalse);

    // 清空后恢复为"强制休息生效"。
    controller.updateTiming(
      quizMinutes: 20,
      restMinutes: 5,
      exemptionWindows: const [],
    );
    await repo.flush();
    expect(controller.isRestExemptNow, isFalse);
    expect(controller.restActiveNow, isTrue);
    expect((await repo.loadOrInit()).exemptionWindows, isEmpty);
  });

  test('V1 旧库迁移到 V2 后支持管理密码列', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('stm_migrate_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'v1.db');

    // 手工创建 V1 结构（app_settings 无 admin_password_hash 列）。
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => applySchemaV1(db),
      ),
    );
    await v1.close();

    // 走应用入口打开：应触发 V2 阶梯迁移而不是重建。
    final db = await openAppDatabase(dbPath: path);
    final repo = AppSettingsRepository(db);
    final settings = await repo.loadOrInit();
    expect(settings.adminPasswordHash, isNull);

    await repo.upsert(settings.copyWith(adminPasswordHash: 'hash123'));
    final reloaded = await repo.loadOrInit();
    expect(reloaded.adminPasswordHash, 'hash123');
  });
}
