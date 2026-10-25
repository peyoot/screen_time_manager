/// 当日快照的恢复与写入：控制器级集成测试。
///
/// 覆盖：运行期快照落库、重启后恢复计时/豁免/休息统计、
/// 休息中恢复继续倒计时、跨天旧快照忽略。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_tempo/data/repositories/day_snapshot_repository.dart';
import 'package:screen_tempo/models/app_settings.dart';
import 'package:screen_tempo/models/day_snapshot.dart';
import 'package:screen_tempo/question_bank/question_bank_service.dart';
import 'package:screen_tempo/state_machine/app_phase.dart';
import 'package:screen_tempo/state_machine/screen_time_machine.dart';
import 'package:screen_tempo/ui/screen_time/screen_time_controller.dart';

import '../data/_helpers.dart';

void main() {
  late DateTime now;
  late DaySnapshotRepository dayRepo;

  setUp(() async {
    now = DateTime(2026, 10, 17, 8, 0);
    final db = await openTestDb();
    dayRepo = DaySnapshotRepository(db);
  });

  ScreenTimeMachine buildMachine() => ScreenTimeMachine(
        settings: AppSettings.defaults.copyWith(
          questionsPerQuiz: 2,
          requiredCorrectCount: 1,
          quizInterval: const Duration(minutes: 15),
          restDuration: const Duration(minutes: 1),
        ),
        clock: () => now,
        initiallyScreenOn: true,
      );

  ScreenTimeController buildController(ScreenTimeMachine machine) {
    final controller = ScreenTimeController(
      machine: machine,
      bankService: QuestionBankService(),
      clock: () => now,
      autoStart: false,
      daySnapshotRepo: dayRepo,
    );
    return controller;
  }

  test('运行期：灭屏时把当日累计写入快照', () async {
    final machine = buildMachine();
    final controller = buildController(machine);
    addTearDown(controller.dispose);

    // 亮屏 30 秒后灭屏：灭屏路径强制固化快照。
    now = now.add(const Duration(seconds: 30));
    machine.tick();
    controller.reportScreenOn(false);
    await dayRepo.flush();

    final snapshot = await dayRepo.loadForDay(now);
    expect(snapshot, isNotNull);
    expect(snapshot!.screenTime, const Duration(seconds: 30));
    expect(snapshot.thresholdProgress, const Duration(seconds: 30));
    expect(snapshot.restCount, 0);
    expect(snapshot.restEndsAt, isNull);
  });

  test('重启恢复：计时、阈值进度、豁免与休息统计全部延续', () async {
    // 模拟被杀前写入的快照。
    await dayRepo.upsert(DaySnapshot(
      day: now,
      screenTime: const Duration(minutes: 20),
      thresholdProgress: const Duration(minutes: 10),
      exemptionsUsedToday: 1,
      restCount: 2,
      restElapsed: const Duration(minutes: 5),
      restExemptions: 1,
    ));
    await dayRepo.flush();

    // 新进程：全新状态机 + 控制器，从快照恢复。
    final machine = buildMachine();
    final controller = buildController(machine);
    addTearDown(controller.dispose);
    await controller.restoreFromSnapshot();

    expect(machine.state.usedToday, const Duration(minutes: 20));
    expect(machine.state.sinceLastGrant, const Duration(minutes: 10));
    expect(machine.state.remainingToQuiz, const Duration(minutes: 5));
    // 默认每日 2 次豁免，快照已用 1 次。
    expect(machine.remainingExemptions, 1);
    expect(controller.todayRestCount, 2);
    expect(controller.todayRestExemptions, 1);
    expect(controller.todayRestDuration, const Duration(minutes: 5));
  });

  test('重启恢复：休息未结束则恢复休息并继续倒计时', () async {
    await dayRepo.upsert(DaySnapshot(
      day: now,
      screenTime: const Duration(minutes: 30),
      restCount: 1,
      restElapsed: const Duration(minutes: 5),
      restEndsAt: now.add(const Duration(minutes: 5)),
    ));
    await dayRepo.flush();

    final machine = buildMachine();
    final controller = buildController(machine);
    addTearDown(controller.dispose);
    await controller.restoreFromSnapshot();

    // 恢复为休息中；当日累计亮屏不丢。
    expect(machine.state.phase, AppPhase.resting);
    expect(machine.state.usedToday, const Duration(minutes: 30));
    expect(controller.todayRestCount, 1);

    // 30 秒后：休息剩余时间减少，"未用本机"统计继续累计。
    now = now.add(const Duration(seconds: 30));
    machine.tick();
    expect(
      machine.state.restEndsAt!.difference(now),
      const Duration(minutes: 4, seconds: 30),
    );
    expect(
      controller.todayRestDuration,
      const Duration(minutes: 5, seconds: 30),
    );
  });

  test('重启恢复：已过期的休息不恢复，按计时阶段继续', () async {
    await dayRepo.upsert(DaySnapshot(
      day: now,
      screenTime: const Duration(minutes: 10),
      restCount: 1,
      restEndsAt: now.subtract(const Duration(minutes: 1)),
    ));
    await dayRepo.flush();

    final machine = buildMachine();
    final controller = buildController(machine);
    addTearDown(controller.dispose);
    await controller.restoreFromSnapshot();

    expect(machine.state.phase, AppPhase.tracking);
    expect(machine.state.usedToday, const Duration(minutes: 10));
  });

  test('跨天旧快照被忽略，不恢复昨日数据', () async {
    await dayRepo.upsert(DaySnapshot(
      day: now.subtract(const Duration(days: 1)),
      screenTime: const Duration(hours: 5),
      restCount: 9,
      restExemptions: 9,
    ));
    await dayRepo.flush();

    final machine = buildMachine();
    final controller = buildController(machine);
    addTearDown(controller.dispose);
    await controller.restoreFromSnapshot();

    expect(machine.state.usedToday, Duration.zero);
    expect(controller.todayRestCount, 0);
    expect(controller.todayRestExemptions, 0);
    expect(machine.remainingExemptions, 2);
  });
}
