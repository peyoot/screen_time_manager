/// 应用入口。
///
/// 启动流程：打开本地 SQLite → 建表 → 加载配置与题库 → 构造状态机与控制器 → 挂载 UI。
/// 平台通道与真实亮屏监听后续接入；当前由控制器内部定时器驱动。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'data/repositories/app_settings_repository.dart';
import 'data/repositories/question_repository.dart';
import 'data/repositories/rest_session_repository.dart';
import 'data/repositories/screen_session_repository.dart';
import 'data/repositories/snooze_record_repository.dart';
import 'models/question.dart';
import 'models/question_bank.dart';
import 'question_bank/bank_question.dart';
import 'question_bank/question_bank_service.dart';
import 'state_machine/screen_time_machine.dart';
import 'ui/locale_controller.dart';
import 'ui/screen_time/home_page.dart';
import 'ui/screen_time/screen_time_controller.dart';

import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openAppDatabase();

  final appSettingsRepo = AppSettingsRepository(db);
  final questionRepo = QuestionRepository(db);
  final screenSessionRepo = ScreenSessionRepository(db);
  final restSessionRepo = RestSessionRepository(db);
  final snoozeRecordRepo = SnoozeRecordRepository(db);

  // 加载配置；首次运行时写入默认值。
  final settings = await appSettingsRepo.loadOrInit();

  // 题库服务：注入 repo 后从 DB 载入分组与权重。
  final bankService = QuestionBankService(repository: questionRepo);
  await bankService.loadFromDb();
  // 首次运行题库为空时塞入示例数据，便于用户体验。
  if (bankService.groups.isEmpty) {
    _seedDemoQuestionBank(bankService);
    await bankService.flush();
  }

  // 状态机用的选择题题库：仅用于阶段流转的答题会话，
  // UI 实际展示的输入式题目来自 [QuestionBankService]。
  final machineBank = QuestionBank(
    id: 'machine',
    name: '状态机题库',
    questions: List.generate(
      10,
      (i) => Question(
        id: 'mq$i',
        prompt: '状态机占位题 $i',
        options: const ['错误', '正确'],
        correctIndex: 1,
      ),
    ),
  );

  final machine = ScreenTimeMachine(
    // 采用 DB 中的配置；仅调整每轮题量为 2 道。
    settings: settings.copyWith(
      questionsPerQuiz: 2,
      requiredCorrectCount: 1,
    ),
    questionBank: machineBank,
    random: Random(2026),
  );

  final controller = ScreenTimeController(
    machine: machine,
    bankService: bankService,
    questionsPerQuiz: 2,
    appSettingsRepo: appSettingsRepo,
    screenSessionRepo: screenSessionRepo,
    restSessionRepo: restSessionRepo,
    snoozeRecordRepo: snoozeRecordRepo,
  );

  runApp(ScreenTimeManagerApp(controller: controller));
}

/// 首次运行时写入示例题库（与原 [QuestionBankService.demo] 内容一致）。
void _seedDemoQuestionBank(QuestionBankService service) {
  service.importIntoNewGroup(
    name: '安全知识',
    questions: [
      BankQuestion(
        question: '发生火灾时，应拨打的火警电话是多少？',
        answer: '119',
        hint: '三位数的应急电话',
      ),
      BankQuestion(
        question: '红灯亮时，行人应该怎么做？',
        answer: '停在路口等待绿灯',
        hint: '遵守交通信号',
      ),
      BankQuestion(
        question: '雷雨天可以在大树下躲雨吗？',
        answer: '不可以',
        hint: '高大的树木容易引雷',
      ),
    ],
  );
  service.importIntoNewGroup(
    name: '生活常识',
    questions: [
      BankQuestion(
        question: '二十四节气中的第一个节气是什么？',
        answer: '立春',
        hint: '春天的开始',
      ),
      BankQuestion(question: '人体最大的器官是什么？', answer: '皮肤'),
      BankQuestion(
        question: '水的化学式是什么？',
        answer: 'H2O',
        hint: '两个氢原子、一个氧原子',
      ),
    ],
  );
  final spare = service.importIntoNewGroup(
    name: '备用题库',
    questions: [
      BankQuestion(question: '圆周率约为多少？（保留两位小数）', answer: '3.14'),
      BankQuestion(question: '光速约为每秒多少万公里？', answer: '30万'),
    ],
  );
  service.setGroupEnabled(spare.id, false);
}

/// 应用根组件。
class ScreenTimeManagerApp extends StatelessWidget {
  final ScreenTimeController controller;

  const ScreenTimeManagerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.localeController,
      builder: (context, _) {
        return MaterialApp(
          title: '屏幕时间管理',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          locale: controller.localeController.locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          home: HomePage(controller: controller),
        );
      },
    );
  }
}
