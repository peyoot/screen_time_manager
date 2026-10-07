/// 应用入口。
///
/// 当前阶段仅挂载题库模块 UI（内存假数据驱动）；
/// 后续将替换为主计时页并接入 ScreenTimeMachine 与平台通道。
library;

import 'package:flutter/material.dart';

import 'question_bank/question_bank_service.dart';
import 'ui/question_bank/group_list_page.dart';

void main() {
  runApp(ScreenTimeManagerApp(service: QuestionBankService.demo()));
}

/// 应用根组件。
class ScreenTimeManagerApp extends StatelessWidget {
  /// 共享的题库服务（内存存储）。
  final QuestionBankService service;

  const ScreenTimeManagerApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '屏幕时间管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: GroupListPage(service: service),
    );
  }
}
