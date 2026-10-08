/// 题库分组管理页：分组列表、新建、导入、编辑、删除与启用开关。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../question_bank/bank_question.dart';
import '../../question_bank/question_bank_service.dart';
import '../../question_bank/question_group.dart';
import 'group_detail_page.dart';
import 'import_sheet.dart';

/// 分组列表条目上的操作菜单项。
enum _GroupAction { edit, import, delete }

/// 题库分组管理页（假数据由 [QuestionBankService] 提供）。
class GroupListPage extends StatelessWidget {
  /// 共享的题库服务。
  final QuestionBankService service;

  const GroupListPage({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bankGroups),
        actions: [
          IconButton(
            tooltip: l10n.bankImportToNew,
            icon: const Icon(Icons.upload_file),
            onPressed: () => _importToNewGroup(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createGroup(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.bankNewGroup),
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final groups = service.groups;
          if (groups.isEmpty) {
            return Center(
              child: Text(l10n.bankEmptyHint),
            );
          }
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildTile(context, groups[index]),
          );
        },
      ),
    );
  }

  /// 构建单个分组条目：名称/题数/类型 + 启用开关 + 操作菜单。
  Widget _buildTile(BuildContext context, QuestionGroup group) {
    final l10n = S.of(context);
    return ListTile(
      title: Text(group.name),
      subtitle: Text(
        l10n.bankGroupSummary(group.questions.length, group.type) +
            (group.enabled ? '' : ' · ${l10n.bankGroupDisabled}'),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupDetailPage(service: service, groupId: group.id),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: group.enabled,
            onChanged: (value) => service.setGroupEnabled(group.id, value),
          ),
          PopupMenuButton<_GroupAction>(
            onSelected: (action) => _onAction(context, action, group),
            itemBuilder: (_) => [
              PopupMenuItem(value: _GroupAction.edit, child: Text(l10n.bankActionEdit)),
              PopupMenuItem(value: _GroupAction.import, child: Text(l10n.bankActionImport)),
              PopupMenuItem(value: _GroupAction.delete, child: Text(l10n.bankActionDelete)),
            ],
          ),
        ],
      ),
    );
  }

  void _onAction(
    BuildContext context,
    _GroupAction action,
    QuestionGroup group,
  ) {
    switch (action) {
      case _GroupAction.edit:
        _renameGroup(context, group);
      case _GroupAction.import:
        _importToGroup(context, group);
      case _GroupAction.delete:
        _confirmDelete(context, group);
    }
  }

  /// 弹出导入面板的统一入口。
  Future<void> _showImportSheet(
    BuildContext context, {
    required String title,
    required bool requireGroupName,
    required void Function(List<BankQuestion> questions, String? groupName)
        onImport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ImportSheet(
          title: title,
          requireGroupName: requireGroupName,
          onImport: onImport,
        ),
      ),
    );
  }

  Future<void> _importToNewGroup(BuildContext context) async {
    await _showImportSheet(
      context,
      title: S.of(context).bankImportToNew,
      requireGroupName: true,
      onImport: (questions, groupName) =>
          service.importIntoNewGroup(name: groupName!, questions: questions),
    );
  }

  Future<void> _importToGroup(BuildContext context, QuestionGroup group) {
    return _showImportSheet(
      context,
      title: S.of(context).bankImportToGroup(group.name),
      requireGroupName: false,
      onImport: (questions, _) => service.addQuestions(group.id, questions),
    );
  }

  /// 弹出单行文本输入对话框，返回去除首尾空白后的输入值。
  Future<String?> _promptForText(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final l10n = S.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
          decoration: InputDecoration(labelText: l10n.bankNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.bankCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.bankConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createGroup(BuildContext context) async {
    final name = await _promptForText(context, title: S.of(context).bankNewGroup);
    if (name == null || name.isEmpty) return;
    service.createGroup(name);
  }

  Future<void> _renameGroup(BuildContext context, QuestionGroup group) async {
    final name = await _promptForText(
      context,
      title: S.of(context).bankRenameGroup,
      initialValue: group.name,
    );
    if (name == null || name.isEmpty) return;
    service.renameGroup(group.id, name);
  }

  Future<void> _confirmDelete(BuildContext context, QuestionGroup group) async {
    final l10n = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.bankDeleteGroup),
        content: Text(l10n.bankDeleteGroupMsg(group.name, group.questions.length)),
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
      service.removeGroup(group.id);
    }
  }
}
