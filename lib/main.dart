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
  // 首次运行题库为空时写入默认题库：所有语种加载英文分组，
  // 中文环境额外追加"文化常识"古诗文飞花令分组。
  if (bankService.groups.isEmpty) {
    final isChinese =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';
    _seedDefaultQuestionBank(bankService, includeChinese: isChinese);
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

/// 首次运行时写入默认题库。
///
/// 默认题库均为英文分组，便于跨语种使用；用户可自行导入所需题库。
/// [includeChinese] 为 true 时额外追加中文"文化常识"古诗文飞花令分组。
void _seedDefaultQuestionBank(
  QuestionBankService service, {
  required bool includeChinese,
}) {
  service.importIntoNewGroup(
    name: 'Missing Piece',
    questions: [
      BankQuestion(
        question: 'Better a cruel truth than a comfortable ___.',
        answer: 'delusion',
        hint: 'Synonym: illusion, false belief',
      ),
      BankQuestion(
        question: 'A journey of a thousand miles begins with a single ___.',
        answer: 'step',
        hint: 'Synonym: pace, stride',
      ),
    ],
  );
  service.importIntoNewGroup(
    name: 'Curious Mind',
    questions: [
      BankQuestion(
        question: 'What is the molecular formula of water?',
        answer: 'H2O',
        hint: 'Two hydrogen atoms and one oxygen atom',
      ),
      BankQuestion(
        question:
            'What is the speed of light in vacuum, approximately (in km/s)?',
        answer: '300000',
        hint: 'About 3 × 10^5 km/s',
      ),
    ],
  );
  if (includeChinese) {
    service.importIntoNewGroup(
      name: '文化常识',
      questions: [
        BankQuestion(
          question: '人闲桂花落，夜静春山___。',
          answer: '空',
          hint: '形容无物、寂静的状态',
        ),
        BankQuestion(
          question: '借问酒家何处有，牧童遥指杏花___。',
          answer: '村',
          hint: '人们聚居的所在',
        ),
      ],
    );
  }
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
