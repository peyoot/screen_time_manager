/// 题库分组详情页：题目列表、手动添加、批量删除。
library;

import 'package:flutter/material.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除所选题目'),
        content: Text('确定删除选中的 ${_selectedIds.length} 道题？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
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
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final group = widget.service.groupById(widget.groupId);
        if (group == null) {
          // 分组已被删除（正常流程下不会走到这里）。
          return Scaffold(
            appBar: AppBar(title: const Text('分组详情')),
            body: const Center(child: Text('分组不存在')),
          );
        }
        final questions = group.questions;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selecting ? '已选 ${_selectedIds.length} 题' : group.name),
            actions: [
              if (!_selecting)
                IconButton(
                  tooltip: '手动添加',
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final question = await _showAddDialog();
                    if (question != null) {
                      widget.service.addQuestions(group.id, [question]);
                    }
                  },
                ),
              IconButton(
                tooltip: _selecting ? '退出选择' : '批量选择',
                icon: Icon(_selecting ? Icons.close : Icons.checklist),
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selectedIds.clear();
                }),
              ),
              if (_selecting)
                IconButton(
                  tooltip: '删除所选',
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _deleteSelected(group),
                ),
            ],
          ),
          body: questions.isEmpty
              ? const Center(child: Text('暂无题目，点击右上角添加'))
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
          Text('答案：${question.answer}'),
          if (question.hint != null && question.hint!.isNotEmpty)
            Text(
              '提示：${question.hint}',
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
      setState(() => _error = '题干和答案不能为空');
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
    return AlertDialog(
      title: const Text('添加题目'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '题干'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(labelText: '答案'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hintController,
              decoration: const InputDecoration(labelText: '提示（可选）'),
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
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
