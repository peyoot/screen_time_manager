/// 题目导入面板：支持 CSV / JSON 两种格式，粘贴文本后解析导入。
library;

import 'package:flutter/material.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/csv_question_parser.dart';
import '../../question_bank/question_group.dart';

/// 支持的导入格式。
enum ImportFormat { csv, json }

/// 底部弹出的导入面板。
///
/// - CSV：表头 `question,answer,hint`，每题一行，支持双引号包裹含逗号字段；
/// - JSON：`{ groupName, type, questions: [{question, answer, hint?}] }`。
///
/// [requireGroupName] 为 true 时（导入到新分组）需要提供分组名：
/// CSV 必填；JSON 留空时使用 JSON 内的 `groupName`。
/// 解析失败时在面板内显示错误信息，不打断用户输入。
class ImportSheet extends StatefulWidget {
  /// 面板标题（如"导入到新分组"）。
  final String title;

  /// 是否需要填写分组名称（导入到新分组时为 true）。
  final bool requireGroupName;

  /// 解析成功后的回调；[ImportSheet.onImport] 的 `groupName` 仅在
  /// [requireGroupName] 为 true 时非空。
  final void Function(List<BankQuestion> questions, String? groupName)
      onImport;

  const ImportSheet({
    super.key,
    required this.title,
    this.requireGroupName = false,
    required this.onImport,
  });

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  ImportFormat _format = ImportFormat.csv;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 校验并解析输入文本，成功后回调并关闭面板，失败则在面板内报错。
  void _submit() {
    final name = _nameController.text.trim();
    try {
      if (_format == ImportFormat.csv) {
        if (widget.requireGroupName && name.isEmpty) {
          setState(() => _error = '请填写分组名称');
          return;
        }
        final questions = parseCsvQuestions(_contentController.text);
        if (questions.isEmpty) {
          setState(() => _error = 'CSV 中没有解析到任何题目');
          return;
        }
        widget.onImport(
          questions,
          widget.requireGroupName ? name : null,
        );
      } else {
        final group = QuestionGroup.parse(_contentController.text);
        if (group.questions.isEmpty) {
          setState(() => _error = 'JSON 中没有解析到任何题目');
          return;
        }
        widget.onImport(
          group.questions,
          widget.requireGroupName ? (name.isEmpty ? group.name : name) : null,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<ImportFormat>(
              segments: const [
                ButtonSegment(
                  value: ImportFormat.csv,
                  icon: Icon(Icons.table_chart),
                  label: Text('CSV'),
                ),
                ButtonSegment(
                  value: ImportFormat.json,
                  icon: Icon(Icons.data_object),
                  label: Text('JSON'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (selection) =>
                  setState(() => _format = selection.first),
            ),
            const SizedBox(height: 12),
            if (widget.requireGroupName) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '分组名称',
                  hintText: 'CSV 必填；JSON 留空则使用 groupName',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _contentController,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: _format == ImportFormat.csv ? 'CSV 内容' : 'JSON 内容',
                hintText: _format == ImportFormat.csv
                    ? 'question,answer,hint\n1+1等于几？,2,提示'
                    : '{"groupName":"我的题库","type":"input",'
                        '"questions":[{"question":"...","answer":"..."}]}',
                border: const OutlineInputBorder(),
              ),
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
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.download),
              label: const Text('导入'),
            ),
          ],
        ),
      ),
    );
  }
}
