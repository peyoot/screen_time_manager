/// 题库分组详情页：题目列表、手动添加、批量删除。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/question_bank_service.dart';
import '../../question_bank/question_group.dart';

/// 展示某个分组内的题目列表。
///
/// 支持两种操作：
/// - 右上角"添加"按钮：弹窗手动添加题目（题干/答案必填，提示可选）；
/// - 右上角"批量选择"按钮：进入选择模式，勾选后批量删除；
///   非选择模式下长按任意条目也可直接进入选择模式。
class GroupDetailPage extends StatefulWidget {
  /// 共享的题库服务。
  final QuestionBankService service;

  /// 要展示的分组 id。
  final String groupId;

  const GroupDetailPage({
    super.key,
    required this.service,
    required this.groupId,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  /// 是否处于批量选择模式。
  bool _selecting = false;

  /// 选择模式下已勾选的题目 id。
  final Set<String> _selectedIds = {};

  /// 退出选择模式并清空勾选。
  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  /// 切换某道题的勾选状态。
  void _toggleSelected(String questionId) {
    setState(() {
      if (!_selectedIds.remove(questionId)) {
        _selectedIds.add(questionId);
      }
    });
  }

  Future<void> _deleteSelected(QuestionGroup group) async {
    final l10n = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.groupDetailDeleteSelectedTitle),
        content: Text(l10n.groupDetailDeleteSelectedMsg(_selectedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.bankCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.bankConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.service.removeQuestions(group.id, List.of(_selectedIds));
      _exitSelection();
    }
  }

  /// 弹出手动添加题目对话框，返回新题目（取消时为 null）。
  Future<BankQuestion?> _showAddDialog() {
    return showDialog<BankQuestion>(
      context: context,
      builder: (_) => const _QuestionEditDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final group = widget.service.groupById(widget.groupId);
        if (group == null) {
          // 分组已被删除（正常流程下不会走到这里）。
          return Scaffold(
            appBar: AppBar(title: Text(l10n.groupDetailTitle)),
            body: Center(child: Text(l10n.groupDetailNotFound)),
          );
        }
        final questions = group.questions;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selecting ? l10n.groupDetailSelected(_selectedIds.length) : group.name),
            actions: [
              if (!_selecting)
                IconButton(
                  tooltip: l10n.groupDetailAddTooltip,
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final question = await _showAddDialog();
                    if (question != null) {
                      widget.service.addQuestions(group.id, [question]);
                    }
                  },
                ),
              IconButton(
                tooltip: _selecting ? l10n.groupDetailExitSelectTooltip : l10n.groupDetailSelectTooltip,
                icon: Icon(_selecting ? Icons.close : Icons.checklist),
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selectedIds.clear();
                }),
              ),
              if (_selecting)
                IconButton(
                  tooltip: l10n.groupDetailDeleteSelectedTooltip,
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _deleteSelected(group),
                ),
            ],
          ),
          body: questions.isEmpty
              ? Center(child: Text(l10n.groupDetailEmpty))
              : ListView.separated(
                  itemCount: questions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildTile(questions[index]),
                ),
        );
      },
    );
  }

  /// 构建单道题目条目：选择模式下显示勾选框，平时显示答案与提示。
  Widget _buildTile(BankQuestion question) {
    final l10n = S.of(context);
    final selected = _selectedIds.contains(question.id);
    return ListTile(
      leading: _selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleSelected(question.id),
            )
          : null,
      title: Text(question.question),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.groupDetailAnswer(question.answer)),
          if (question.hint != null && question.hint!.isNotEmpty)
            Text(
              l10n.groupDetailHint(question.hint!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: _selecting ? () => _toggleSelected(question.id) : null,
      onLongPress: _selecting
          ? null
          : () => setState(() {
                _selecting = true;
                _selectedIds.add(question.id);
              }),
    );
  }
}

/// 手动添加题目的对话框；提交前校验题干与答案非空。
class _QuestionEditDialog extends StatefulWidget {
  const _QuestionEditDialog();

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _hintController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  /// 校验输入并关闭对话框返回新题目；校验失败则在对话框内报错。
  void _submit() {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();
    final hint = _hintController.text.trim();
    if (question.isEmpty || answer.isEmpty) {
      setState(() => _error = S.of(context).groupDetailAddRequired);
      return;
    }
    Navigator.of(context).pop(
      BankQuestion(
        question: question,
        answer: answer,
        hint: hint.isEmpty ? null : hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(l10n.groupDetailAddTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.groupDetailQuestionLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerController,
              decoration: InputDecoration(labelText: l10n.groupDetailAnswerLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hintController,
              decoration: InputDecoration(labelText: l10n.groupDetailHintLabel),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bankCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.groupDetailAddConfirm)),
      ],
    );
  }
}
