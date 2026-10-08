/// 题库分组详情页：题目列表、手动添加、编辑、批量删除。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/question_bank_service.dart';
import '../../question_bank/question_group.dart';

/// 展示某个分组内的题目列表。
///
/// 支持三种操作：
/// - 右上角"添加"按钮：弹窗手动添加题目（题干/答案必填，提示可选）；
/// - 每个条目右侧"编辑"按钮：弹窗预填并修改题目（id 保持不变）；
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

  /// 弹出题目编辑对话框；[initial] 为空时表示新增，非空时预填题目内容。
  /// 返回编辑后的题目（取消时为 null）。
  Future<BankQuestion?> _showQuestionDialog({BankQuestion? initial}) {
    return showDialog<BankQuestion>(
      context: context,
      builder: (_) => _QuestionEditDialog(initial: initial),
    );
  }

  /// 编辑指定题目：弹出预填对话框，确认后写回题库（id 保持不变）。
  Future<void> _editQuestion(QuestionGroup group, BankQuestion question) async {
    final updated = await _showQuestionDialog(initial: question);
    if (updated == null) return;
    widget.service.updateQuestion(
      group.id,
      question.id,
      question: updated.question,
      answer: updated.answer,
      hint: updated.hint,
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
                    final question = await _showQuestionDialog();
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

  /// 构建单道题目条目：选择模式下显示勾选框，平时显示答案、提示与编辑入口。
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
      trailing: _selecting
          ? null
          : IconButton(
              tooltip: l10n.groupDetailEditTooltip,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final group = widget.service.groupById(widget.groupId);
                if (group != null) _editQuestion(group, question);
              },
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

/// 题目新增/编辑对话框；提交前校验题干与答案非空。
///
/// 传入 [initial] 时进入编辑模式：预填原有内容、使用编辑标题与确认文案；
/// 返回的对象在编辑模式下保留原 id，新增时由模型自动生成。
class _QuestionEditDialog extends StatefulWidget {
  /// 编辑模式下的原题；为 null 表示新增。
  final BankQuestion? initial;

  const _QuestionEditDialog({this.initial});

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _hintController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.initial?.question ?? '');
    _answerController =
        TextEditingController(text: widget.initial?.answer ?? '');
    _hintController = TextEditingController(text: widget.initial?.hint ?? '');
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  /// 校验输入并关闭对话框返回题目；校验失败则在对话框内报错。
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
        id: widget.initial?.id,
        question: question,
        answer: answer,
        hint: hint.isEmpty ? null : hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? l10n.groupDetailEditTitle : l10n.groupDetailAddTitle),
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
        FilledButton(
          onPressed: _submit,
          child: Text(
            isEditing ? l10n.groupDetailEditConfirm : l10n.groupDetailAddConfirm,
          ),
        ),
      ],
    );
  }
}
