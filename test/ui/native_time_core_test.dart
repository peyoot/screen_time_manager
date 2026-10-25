/// 原生权威计时核心（TimeCore）在 Dart 侧的接线测试：
/// - TimeCoreSnapshot.fromMap 解析（含毫秒 0 → null 映射）；
/// - ScreenTimeMachine.applyNativeSnapshot 镜像语义；
/// - 控制器原生模式的快照镜像 / 操作转发 / 本地副作用抑制。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_tempo/models/app_settings.dart';
import 'package:screen_tempo/platform_channel/platform_channels.dart';
import 'package:screen_tempo/question_bank/bank_question.dart';
import 'package:screen_tempo/question_bank/question_bank_service.dart';
import 'package:screen_tempo/state_machine/app_phase.dart';
import 'package:screen_tempo/state_machine/screen_time_machine.dart';
import 'package:screen_tempo/ui/screen_time/screen_time_controller.dart';

/// 构造一个原生快照（默认全部来自"今日已有数据"）。
TimeCoreSnapshot _snap({
  Duration used = Duration.zero,
  Duration threshold = Duration.zero,
  int exemptions = 0,
  bool resting = false,
  DateTime? restEndsAt,
  DateTime? restStart,
  bool screenOn = true,
  int restCount = 0,
  Duration restCompleted = Duration.zero,
  int restExemptions = 0,
  bool hasDayData = true,
  Duration away = Duration.zero,
  DateTime? pendingAwayStart,
}) =>
    TimeCoreSnapshot(
      usedToday: used,
      thresholdProgress: threshold,
      exemptionsUsedToday: exemptions,
      resting: resting,
      restEndsAt: restEndsAt,
      restStart: restStart,
      isScreenOn: screenOn,
      restCount: restCount,
      restCompleted: restCompleted,
      restExemptions: restExemptions,
      hasDayData: hasDayData,
      away: away,
      pendingAwayStart: pendingAwayStart,
    );

/// 可编排的假计时核心。
class _FakeTimeCore implements TimeCore {
  _FakeTimeCore(this.snapshotValue);

  TimeCoreSnapshot snapshotValue;
  AppSettings? configuredSettings;
  int manualRestCalls = 0;
  int consumeExemptionCalls = 0;
  Duration? seededUsedToday;
  bool seedAccepted = false;
  bool failSnapshot = false;
  final DateTime _restEndsAt = DateTime(2026, 10, 11, 9, 30);

  @override
  Future<TimeCoreSnapshot> snapshot() async {
    if (failSnapshot) {
      throw PlatformException(code: 'core-unavailable');
    }
    return snapshotValue;
  }

  @override
  Future<void> configure(AppSettings settings) async {
    configuredSettings = settings;
  }

  @override
  Future<void> manualRest() async {
    manualRestCalls++;
    snapshotValue = _snap(
      used: snapshotValue.usedToday,
      restCount: snapshotValue.restCount + 1,
      restCompleted: snapshotValue.restCompleted,
      restExemptions: snapshotValue.restExemptions,
      exemptions: snapshotValue.exemptionsUsedToday,
      resting: true,
      restStart: DateTime(2026, 10, 11, 9, 0),
      restEndsAt: _restEndsAt,
    );
  }

  @override
  Future<void> consumeExemption() async {
    consumeExemptionCalls++;
    snapshotValue = _snap(
      used: snapshotValue.usedToday,
      restCount: snapshotValue.restCount,
      restCompleted: snapshotValue.restCompleted +
          const Duration(minutes: 2),
      restExemptions: snapshotValue.restExemptions + 1,
      exemptions: snapshotValue.exemptionsUsedToday + 1,
      resting: false,
    );
  }

  @override
  Future<bool> seedFromSnapshot({
    required Duration usedToday,
    required Duration thresholdProgress,
    required int exemptionsUsedToday,
    required bool resting,
    DateTime? restEndsAt,
  }) async {
    seededUsedToday = usedToday;
    if (seedAccepted) {
      snapshotValue = _snap(
        used: usedToday,
        threshold: thresholdProgress,
        exemptions: exemptionsUsedToday,
        resting: resting,
        restEndsAt: restEndsAt,
      );
    }
    return seedAccepted;
  }
}

/// 记录调用的假干预桥（原生模式下应保持零调用）。
class _RecordingInterventionBridge implements InterventionBridge {
  int requestCount = 0;
  int dismissCount = 0;
  int startPinCount = 0;
  int stopPinCount = 0;

  @override
  Future<void> request(InterventionPhase phase) async => requestCount++;
  @override
  Future<void> dismiss() async => dismissCount++;
  @override
  Future<bool> lockScreen() async => false;
  @override
  Future<bool> get isDeviceAdminEnabled async => false;
  @override
  Future<void> openDeviceAdminSettings() async {}
  @override
  Future<bool> startScreenPinning() async {
    startPinCount++;
    return true;
  }

  @override
  Future<bool> stopScreenPinning() async {
    stopPinCount++;
    return true;
  }
}

QuestionBankService _bankWithOneQuestion() {
  final service = QuestionBankService();
  service.importIntoNewGroup(
    name: 'g',
    questions: [BankQuestion(question: 'What is water?', answer: 'H2O')],
  );
  return service;
}

ScreenTimeMachine _machine(DateTime Function() clock) => ScreenTimeMachine(
      settings: AppSettings(
        quizInterval: const Duration(minutes: 15),
        questionsPerQuiz: 1,
        requiredCorrectCount: 1,
        restDuration: const Duration(minutes: 3),
      ),
      clock: clock,
      initiallyScreenOn: true,
    );

void main() {
  group('TimeCoreSnapshot.fromMap', () {
    test('完整解析并把毫秒 0 映射为 null', () {
      final s = TimeCoreSnapshot.fromMap(<String, dynamic>{
        'dayKey': '2026-10-11',
        'screenTimeSec': 300,
        'thresholdSec': 120,
        'exemptionsUsedToday': 1,
        'resting': true,
        'restEndsAtMs': 1000,
        'restStartMs': 500,
        'restCount': 2,
        'restElapsedSec': 60,
        'restExemptions': 1,
        'isScreenOn': true,
        'quizIntervalSec': 900,
        'restDurationSec': 600,
        'dailyExemptionLimit': 2,
        'hasDayData': true,
        'awaySec': 1800,
        'pendingAwayStartMs': 2000,
      });
      expect(s.usedToday, const Duration(seconds: 300));
      expect(s.thresholdProgress, const Duration(seconds: 120));
      expect(s.exemptionsUsedToday, 1);
      expect(s.resting, isTrue);
      expect(s.restEndsAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(s.restStart, DateTime.fromMillisecondsSinceEpoch(500));
      expect(s.restCount, 2);
      expect(s.restCompleted, const Duration(seconds: 60));
      expect(s.restExemptions, 1);
      expect(s.isScreenOn, isTrue);
      expect(s.hasDayData, isTrue);
      expect(s.away, const Duration(seconds: 1800));
      expect(s.pendingAwayStart,
          DateTime.fromMillisecondsSinceEpoch(2000));
    });

    test('空 Map 解析为全零、时刻为 null', () {
      final s = TimeCoreSnapshot.fromMap(const <String, dynamic>{});
      expect(s.usedToday, Duration.zero);
      expect(s.exemptionsUsedToday, 0);
      expect(s.resting, isFalse);
      expect(s.restEndsAt, isNull);
      expect(s.restStart, isNull);
      expect(s.hasDayData, isFalse);
      expect(s.away, Duration.zero);
      expect(s.pendingAwayStart, isNull);
    });
  });

  group('ScreenTimeMachine.applyNativeSnapshot', () {
    test('镜像字段；无变化时不通知', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      var notifications = 0;
      machine.addListener(() => notifications++);

      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 2),
        exemptionsUsedToday: 1,
        isScreenOn: true,
        resting: false,
      );
      expect(notifications, 1);
      expect(machine.state.usedToday, const Duration(minutes: 5));
      expect(machine.state.sinceLastGrant, const Duration(minutes: 2));
      expect(machine.state.exemptionsUsedToday, 1);
      expect(machine.state.isScreenOn, isTrue);
      expect(machine.state.phase, AppPhase.tracking);

      // 相同字段再次应用：不通知。
      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 2),
        exemptionsUsedToday: 1,
        isScreenOn: true,
        resting: false,
      );
      expect(notifications, 1);
    });

    test('resting 且截止未过 → 恢复为休息中', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 15),
        exemptionsUsedToday: 0,
        isScreenOn: true,
        resting: true,
        restEndsAt: now.add(const Duration(minutes: 3)),
      );
      expect(machine.state.phase, AppPhase.resting);
      expect(machine.state.restEndsAt, now.add(const Duration(minutes: 3)));
    });

    test('镜像 awayClosed 与 pendingAwayStart', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final pending = now.subtract(const Duration(minutes: 20));
      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 2),
        exemptionsUsedToday: 0,
        isScreenOn: false,
        resting: false,
        awayClosed: const Duration(minutes: 30),
        pendingAwayStart: pending,
      );
      expect(machine.state.awayClosed, const Duration(minutes: 30));
      expect(machine.state.pendingAwayStart, pending);

      // 无挂起片段：pending 映射为 null。
      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: const Duration(minutes: 2),
        exemptionsUsedToday: 0,
        isScreenOn: false,
        resting: false,
        awayClosed: const Duration(minutes: 30),
      );
      expect(machine.state.pendingAwayStart, isNull);
    });

    test('resting 但截止已过 → 按计时阶段继续', () {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      machine.applyNativeSnapshot(
        usedToday: const Duration(minutes: 5),
        thresholdProgress: Duration.zero,
        exemptionsUsedToday: 0,
        isScreenOn: true,
        resting: true,
        restEndsAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(machine.state.phase, AppPhase.tracking);
    });
  });

  group('控制器原生镜像模式', () {
    test('restoreFromSnapshot 直接镜像原生快照与休息统计', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap(
        used: const Duration(minutes: 8),
        threshold: const Duration(minutes: 3),
        exemptions: 1,
        restCount: 2,
        restCompleted: const Duration(minutes: 10),
        restExemptions: 1,
      ));
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      await controller.restoreFromSnapshot();

      expect(machine.state.usedToday, const Duration(minutes: 8));
      expect(machine.state.sinceLastGrant, const Duration(minutes: 3));
      expect(machine.state.exemptionsUsedToday, 1);
      expect(controller.todayRestCount, 2);
      expect(controller.todayRestDuration, const Duration(minutes: 10));
      expect(controller.todayRestExemptions, 1);
    });

    test('手动休息转发原生、镜像原生统计，且不触发 Dart 本地干预', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap(screenOn: true));
      final bridge = _RecordingInterventionBridge();
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        interventionBridge: bridge,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      controller.manualRest();
      await pumpEventQueue();

      expect(core.manualRestCalls, 1);
      expect(machine.state.phase, AppPhase.resting);
      // 原生权威模式下 Dart 不重复请求干预/固定。
      expect(bridge.requestCount, 0);
      expect(bridge.startPinCount, 0);
      // 当日次数来自原生快照（镜像），非 Dart 本地自增。
      expect(controller.todayRestCount, 1);
    });

    test('休息期答题豁免转发原生消耗额度', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap(
        resting: true,
        restStart: now,
        restEndsAt: now.add(const Duration(minutes: 3)),
        restCount: 1,
      ));
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      await controller.restoreFromSnapshot();
      expect(machine.state.phase, AppPhase.resting);

      controller.requestRestExemption();
      expect(controller.submitRestAnswer('H2O'), isTrue);
      await pumpEventQueue();

      expect(core.consumeExemptionCalls, 1);
      expect(machine.state.phase, AppPhase.tracking);
      expect(controller.todayRestExemptions, 1);
    });

    test('原生无当日数据时用 DB 快照 seed 迁移', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap(hasDayData: false));
      core.seedAccepted = true;
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        // 无 DB repo：seed 走空路径，仅验证"无数据时不破坏现有状态"。
        autoStart: false,
      );
      addTearDown(controller.dispose);

      await controller.restoreFromSnapshot();
      expect(machine.state.phase, AppPhase.tracking);
    });

    test('快照通道异常时静默跳过，不影响既有状态', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap())..failSnapshot = true;
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      await controller.restoreFromSnapshot();
      expect(machine.state.usedToday, Duration.zero);
    });

    test('away 统计镜像：休息中实时部分 + 挂起片段实时部分', () async {
      final now = DateTime(2026, 10, 11, 9, 0);
      final machine = _machine(() => now);
      final core = _FakeTimeCore(_snap(
        resting: true,
        // 与 _machine 的 restDuration=3min 保持一致：restStart..endsAt 共 3 分钟。
        restStart: now.subtract(const Duration(minutes: 1)),
        restEndsAt: now.add(const Duration(minutes: 2)),
        restCount: 1,
        away: const Duration(minutes: 30),
      ));
      final controller = ScreenTimeController(
        machine: machine,
        bankService: _bankWithOneQuestion(),
        questionsPerQuiz: 1,
        timeCore: core,
        clock: () => now,
        autoStart: false,
      );
      addTearDown(controller.dispose);

      await controller.restoreFromSnapshot();
      // 休息中：已完结 30 分钟 + 进行中片段 [restStart, now] = 1 分钟。
      expect(controller.todayAwayDuration, const Duration(minutes: 31));

      // 休息结束屏幕熄灭 → 原生挂起片段；镜像后实时部分按 [pending, now] 计。
      core.snapshotValue = _snap(
        resting: false,
        screenOn: false,
        restCount: 1,
        restCompleted: const Duration(minutes: 10),
        away: const Duration(minutes: 30),
        pendingAwayStart: now.subtract(const Duration(minutes: 15)),
      );
      await controller.restoreFromSnapshot();
      expect(controller.todayAwayDuration, const Duration(minutes: 45));
    });
  });
}
