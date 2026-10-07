/// 答题豁免页：展示输入式题目，用户作答后豁免继续使用。
library;

import 'package:flutter/material.dart';

import '../../state_machine/app_phase.dart';
import 'screen_time_controller.dart';

/// 答题豁免页。
///
/// 逐题展示从题库抽取的 [BankQuestion]，每题包含：
/// - 题干文本
/// - 答案输入框
/// - "查看提示"按钮（展示 hint）
/// 提交后根据对错推进状态机会话，全部作答完毕自动流转。
class QuizPage extends StatefulWidget {
  final ScreenTimeController controller;

  const QuizPage({super.key, required this.controller});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _inputController = TextEditingController();
  bool _hintVisible = false;
  String? _errorText;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = '请输入答案');
      return;
    }
    widget.controller.submitAnswer(input);
    // 提交后由控制器推进；若仍在答题则重置输入。
    if (widget.controller.phase == AppPhase.quiz) {
      _inputController.clear();
      setState(() {
        _hintVisible = false;
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final questions = controller.quizQuestions;
    final theme = Theme.of(context);

    if (questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('题库题目不足，无法答题豁免'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.giveUp,
                child: const Text('去休息'),
              ),
            ],
          ),
        ),
      );
    }

    final index = controller.quizIndex.clamp(0, questions.length - 1);
    final question = questions[index];

    return Scaffold(
      appBar: AppBar(
        title: Text('答题豁免（${index + 1}/${questions.length}）'),
        leading: IconButton(
          tooltip: '放弃答题',
          icon: const Icon(Icons.close),
          onPressed: controller.giveUp,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                question.question,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _inputController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '你的答案',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              if (question.hint != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _hintVisible = true),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('查看提示'),
                  ),
                ),
              if (_hintVisible && question.hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '提示：${question.hint}',
                    style: TextStyle(color: theme.colorScheme.tertiary),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text('提交答案'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
