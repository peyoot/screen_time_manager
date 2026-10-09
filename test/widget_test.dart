import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/main.dart';
import 'package:screen_time_manager/models/app_settings.dart';
import 'package:screen_time_manager/models/question.dart';
import 'package:screen_time_manager/models/question_bank.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';
import 'package:screen_time_manager/state_machine/app_phase.dart';
import 'package:screen_time_manager/state_machine/screen_time_machine.dart';
import 'package:screen_time_manager/ui/screen_time/screen_time_controller.dart';

ScreenTimeController buildController() {
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
    ),
    questionBank: machineBank,
    random: Random(2026),
  );
  return ScreenTimeController(
    machine: machine,
    bankService: bankService,
    questionsPerQuiz: 2,
    autoStart: false,
  );
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
    expect(find.text('Exemptions left'), findsOneWidget);
    // 默认每日 2 次豁免，初始剩余 2 次。
    expect(find.text('2'), findsOneWidget);
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
    // 消耗一次后剩余 1 次（默认每日 2 次）。
    expect(find.text('1 次'), findsOneWidget);
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
    expect(find.text('Please enter positive integers'), findsOneWidget);
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
}
