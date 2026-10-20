import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/l10n/app_localizations.dart';
import 'package:screen_time_manager/main.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/platform_channel/platform_channels.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';
import 'package:screen_time_manager/state_machine/app_phase.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';
import 'package:screen_time_manager/ui/permissions/permission_guide_page.dart';
import 'package:screen_time_manager/ui/screen_time/screen_time_controller.dart';

ScreenTimeController buildController({bool restEnabled = true}) {
  final bankService = QuestionBankService.demo();
  final machineBank = QuestionBank(
    id: 'machine',
    name: '状态机题库',
    questions: List.generate(
      10,
      (i) => Question(
        id: 'mq$i',
        prompt: '占位题 $i',
        options: const ['错误', '正确'],
        correctIndex: 1,
      ),
    ),
  );
  final machine = ScreenTimeMachine(
    settings: AppSettings(
      quizInterval: const Duration(minutes: 30),
      questionsPerQuiz: 2,
      requiredCorrectCount: 1,
      restDuration: const Duration(minutes: 3),
      restEnabled: restEnabled,
    ),
    questionBank: machineBank,
  );
  return ScreenTimeController(
    machine: machine,
    bankService: bankService,
    questionsPerQuiz: 2,
    autoStart: false,
  );
}

/// 假监控通道：返回预置权限状态并记录设置页跳转请求。
class _FakeMonitorChannel extends MonitorChannel {
  _FakeMonitorChannel(this._status);

  final Map<MonitorPermission, bool> _status;
  MonitorPermission? lastOpened;

  @override
  Future<Map<MonitorPermission, bool>> getPermissions() async => _status;

  @override
  Future<void> openPermissionSettings(MonitorPermission permission) async {
    lastOpened = permission;
  }
}

void main() {
  testWidgets('主计时页正常渲染', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 主计时页的核心元素（测试环境默认 locale 为 en）。
    expect(find.text('Screen Time Manager'), findsOneWidget);
    expect(find.text('Screen time today'), findsOneWidget);
    expect(find.text('Take a break now'), findsOneWidget);
    // 默认每日 2 次豁免，初始剩余 2 次；当日尚未豁免休息。
    expect(find.text('Exemptions available: 2'), findsOneWidget);
    expect(find.text('Rest exemptions today: 0'), findsOneWidget);
  });

  testWidgets('从主计时页可跳转到题库分组管理页', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 点击右上角题库入口（英文环境下 tooltip 为英文）。
    await tester.tap(find.byTooltip('Question bank'));
    await tester.pumpAndSettle();

    // 题库分组页正常渲染。
    expect(find.text('Question Groups'), findsOneWidget);
    expect(find.text('Missing Piece'), findsOneWidget);
    expect(find.text('Curious Mind'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('语言切换后界面文本更新', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 测试环境默认 locale 为英文。
    expect(find.text('Screen Time Manager'), findsOneWidget);

    // 切换到中文。
    controller.localeController.setLocale(const Locale('zh'));
    await tester.pumpAndSettle();
    expect(find.text('屏幕时间管理'), findsOneWidget);
    expect(find.text('今日累计亮屏'), findsOneWidget);

    // 切换到日文。
    controller.localeController.setLocale(const Locale('ja'));
    await tester.pumpAndSettle();
    expect(find.text('スクリーンタイム管理'), findsOneWidget);

    // 恢复系统语言（null 表示跟随系统，测试环境默认 en）。
    controller.localeController.setLocale(null);
    await tester.pumpAndSettle();
    expect(find.text('Screen Time Manager'), findsOneWidget);
  });

  testWidgets('休息页豁免：答错显示正确答案可重试，答对提前结束休息', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 切换到中文以便断言文本。
    controller.localeController.setLocale(const Locale('zh'));
    await tester.pumpAndSettle();

    // 手动触发休息，进入休息页。
    await tester.tap(find.text('手动触发休息'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('休息中'), findsOneWidget);

    // 申请豁免：随机抽出一道题。
    await tester.tap(find.text('申请豁免'));
    await tester.pump(const Duration(milliseconds: 100));
    final firstQuestion = controller.restQuizQuestion;
    expect(firstQuestion, isNotNull);

    // 答错：显示正确答案与"再试一次"。
    await tester.enterText(find.byType(TextField), '随便写的答案');
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.restQuizFailed, isTrue);
    expect(find.textContaining('正确答案'), findsOneWidget);
    expect(find.text('再试一次'), findsOneWidget);

    // 再试一次：重新抽题，回到输入形态。
    await tester.ensureVisible(find.text('再试一次'));
    await tester.tap(find.text('再试一次'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.restQuizFailed, isFalse);
    expect(find.byType(TextField), findsOneWidget);

    // 用控制器里的题目答案作答：提前结束休息，回到计时页。
    await tester.enterText(
      find.byType(TextField),
      controller.restQuizQuestion!.answer,
    );
    await tester.ensureVisible(find.text('提交答案'));
    await tester.tap(find.text('提交答案'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.phase, AppPhase.tracking);
    expect(find.text('休息中'), findsNothing);
    expect(find.text('今日累计亮屏'), findsOneWidget);
    // 消耗一次后剩余 1 次（默认每日 2 次），今日共豁免 1 次。
    expect(find.text('本轮可用豁免 1 次'), findsOneWidget);
    expect(find.text('今日共豁免休息 1 次'), findsOneWidget);
  });

  testWidgets('每日豁免次数用完后休息页不再显示申请入口', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();
    controller.localeController.setLocale(const Locale('zh'));
    await tester.pumpAndSettle();

    // 连续两次：手动休息 → 申请豁免 → 答对提前结束。
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('手动触发休息'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('申请豁免'));
      await tester.tap(find.text('申请豁免'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.restQuizQuestion, isNotNull);
      await tester.enterText(
        find.byType(TextField),
        controller.restQuizQuestion!.answer,
      );
      await tester.ensureVisible(find.text('提交答案'));
      await tester.tap(find.text('提交答案'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.phase, AppPhase.tracking);
    }

    expect(controller.remainingExemptions, 0);

    // 第三次休息：申请入口消失，只显示"次数用完"提示。
    await tester.tap(find.text('手动触发休息'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('申请豁免'), findsNothing);
    expect(find.text('今日豁免次数已用完，请等待休息结束'), findsOneWidget);
  });

  testWidgets('后台运行按钮渲染；无平台通道时点击安全 no-op', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 右上角"后台运行"退出按钮（测试环境 monitor 为 null，点击应静默 no-op）。
    final button = find.byTooltip('Run in background');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Screen Time Manager'), findsOneWidget);
  });

  testWidgets('设置管理密码后：权限入口需先验证，错误不放行、正确才进入',
      (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    controller.updateAdminPassword('abcd');

    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 点击权限引导：先弹密码框，权限页尚未进入。
    await tester.tap(find.byTooltip('Permissions'));
    await tester.pumpAndSettle();
    expect(find.text('Enter admin password'), findsOneWidget);
    expect(find.text('Permissions & Reliability'), findsNothing);

    // 输错：显示错误，权限页仍不出现。
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('Permissions & Reliability'), findsNothing);

    // 输对：门禁放行，进入权限引导页。
    await tester.enterText(find.byType(TextField), 'abcd');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Permissions & Reliability'), findsOneWidget);
  });

  testWidgets('权限引导页展示精确闹钟条目：未授权标红，点击请求跳转对应设置页',
      (tester) async {
    final monitor = _FakeMonitorChannel(const {
      MonitorPermission.overlay: true,
      MonitorPermission.exactAlarm: false,
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: PermissionGuidePage(monitor: monitor),
      ),
    );
    await tester.pumpAndSettle();

    // 新条目渲染（测试环境默认 en locale）：未授权显示 Not granted。
    expect(find.text('Exact alarms'), findsOneWidget);
    expect(find.text('Not granted'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);

    // 点击条目 → 请求跳转 exactAlarm 设置页。
    await tester.tap(find.text('Exact alarms'));
    await tester.pumpAndSettle();
    expect(monitor.lastOpened, MonitorPermission.exactAlarm);
  });

  testWidgets('计时设置对话框可修改亮屏与休息时长', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 初始为测试配置 30 分钟亮屏 / 3 分钟休息。
    expect(
      controller.machine.settings.quizInterval,
      const Duration(minutes: 30),
    );

    // 打开设置（英文环境 tooltip）。
    await tester.tap(find.byTooltip('Timing settings'));
    await tester.pumpAndSettle();
    expect(find.text('Timing settings'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // 非法输入（0）不允许保存，对话框保持打开并报错。
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter an integer between 1 and 99'), findsOneWidget);
    expect(controller.machine.settings.quizInterval,
        const Duration(minutes: 30));

    // 合法输入：亮屏 1 分钟、休息 1 分钟。
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      controller.machine.settings.quizInterval,
      const Duration(minutes: 1),
    );
    expect(
      controller.machine.settings.restDuration,
      const Duration(minutes: 1),
    );
  });

  testWidgets('强制休息关闭：主页显示未启用文案、隐藏手动休息按钮、亮屏照常统计',
      (tester) async {
    final controller = buildController(restEnabled: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 今日亮屏照常显示；倒计时行变为"强制休息未启用"；手动休息按钮隐藏。
    expect(find.text('Screen time today'), findsOneWidget);
    expect(find.text('Forced rest disabled'), findsOneWidget);
    expect(find.text('Take a break now'), findsNothing);

    // 控制器手动休息入口静默忽略，不会进入休息页。
    controller.manualRest();
    await tester.pumpAndSettle();
    expect(controller.phase, AppPhase.tracking);
    expect(find.text('Forced rest disabled'), findsOneWidget);
  });

  testWidgets('设置对话框关闭强制休息开关并保存后主页联动', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenTimeManagerApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // 初始启用：显示倒计时文案与手动休息按钮。
    expect(find.text('Take a break now'), findsOneWidget);
    expect(find.text('Forced rest disabled'), findsNothing);

    // 打开设置：开关初始为开。
    await tester.tap(find.byTooltip('Timing settings'));
    await tester.pumpAndSettle();
    expect(find.text('Forced rest'), findsOneWidget);
    final switchTile = find.byType(SwitchListTile);
    expect(switchTile, findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(switchTile).value,
      isTrue,
    );

    // 关闭开关并保存：主页文案与按钮联动。
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.machine.settings.restEnabled, isFalse);
    expect(find.text('Forced rest disabled'), findsOneWidget);
    expect(find.text('Take a break now'), findsNothing);

    // 重新打开设置恢复开关。
    await tester.tap(find.byTooltip('Timing settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.machine.settings.restEnabled, isTrue);
    expect(find.text('Take a break now'), findsOneWidget);
  });
}
