/// 应用入口。
///
/// 假数据驱动阶段：创建内存题库服务与状态机，由 [ScreenTimeController]
/// 桥接后挂载主计时页。平台通道与真实亮屏监听后续接入。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'models/question.dart';
import 'models/question_bank.dart';
import 'question_bank/question_bank_service.dart';
import 'state_machine/screen_time_machine.dart';
import 'ui/screen_time/home_page.dart';
import 'ui/screen_time/screen_time_controller.dart';

void main() {
  final bankService = QuestionBankService.demo();

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
    settings: AppSettings(
      quizInterval: const Duration(minutes: 30),
      questionsPerQuiz: 2,
      requiredCorrectCount: 1,
      restDuration: const Duration(minutes: 3),
    ),
    questionBank: machineBank,
    random: Random(2026),
  );

  final controller = ScreenTimeController(
    machine: machine,
    bankService: bankService,
    questionsPerQuiz: 2,
  );

  runApp(ScreenTimeManagerApp(controller: controller));
}

/// 应用根组件。
class ScreenTimeManagerApp extends StatelessWidget {
  final ScreenTimeController controller;

  const ScreenTimeManagerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '屏幕时间管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HomePage(controller: controller),
    );
  }
}
