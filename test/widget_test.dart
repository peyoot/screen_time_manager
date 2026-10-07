import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_manager/main.dart';
import 'package:screen_time_manager/question_bank/question_bank_service.dart';

void main() {
  testWidgets('题库分组管理页冒烟测试', (tester) async {
    await tester.pumpWidget(
      ScreenTimeManagerApp(service: QuestionBankService.demo()),
    );

    // AppBar 与示例分组均正常渲染。
    expect(find.text('题库分组'), findsOneWidget);
    expect(find.text('安全知识'), findsOneWidget);
    expect(find.text('生活常识'), findsOneWidget);
    expect(find.text('备用题库'), findsOneWidget);
    expect(find.text('新建分组'), findsOneWidget);

    // 示例数据中"备用题库"为停用状态，每个分组都带一个启用开关。
    expect(find.byType(Switch), findsNWidgets(3));
  });
}
