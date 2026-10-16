/// 本机管理密码相关对话框：解锁验证与设置/修改。
///
/// 管理密码用于防儿童随意修改配置：设置后，进入设置对话框与题库管理页
/// 都需要先通过 [promptAdminPassword] 验证。密码只存加盐哈希（见控制器），
/// 清除/修改都在已通过验证的设置对话框内进行。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'screen_time_controller.dart';

/// 管理密码最短长度（过短起不到门禁作用，过长对儿童家长都不友好）。
const int kAdminPasswordMinLength = 4;

/// 弹出管理密码验证框；验证通过返回 true，取消或密码错误返回 false。
Future<bool> promptAdminPassword(
  BuildContext context,
  ScreenTimeController controller,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _AdminPasswordPromptDialog(controller: controller),
  );
  return result ?? false;
}

/// 已设置管理密码时的门禁：先验证，通过后执行 [open]；未设置则直接执行。
Future<void> openWithAdminGate(
  BuildContext context,
  ScreenTimeController controller,
  void Function() open,
) async {
  if (!controller.hasAdminPassword) {
    open();
    return;
  }
  final ok = await promptAdminPassword(context, controller);
  if (ok && context.mounted) open();
}

/// 弹出设置/修改管理密码对话框（两个字段：新密码 + 确认）。
Future<void> showSetAdminPasswordDialog(
  BuildContext context,
  ScreenTimeController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SetAdminPasswordDialog(controller: controller),
  );
}

/// 管理密码验证框：输错时在框内提示，可重试。
class _AdminPasswordPromptDialog extends StatefulWidget {
  final ScreenTimeController controller;

  const _AdminPasswordPromptDialog({required this.controller});

  @override
  State<_AdminPasswordPromptDialog> createState() =>
      _AdminPasswordPromptDialogState();
}

class _AdminPasswordPromptDialogState
    extends State<_AdminPasswordPromptDialog> {
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.controller.verifyAdminPassword(_passwordController.text)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = S.of(context).adminPasswordWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      title: Text(l10n.adminPasswordEnterTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.adminPasswordFieldLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.bankCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.adminPasswordConfirm),
        ),
      ],
    );
  }
}

/// 设置/修改管理密码对话框：新密码 + 确认，校验一致性与最短长度。
class _SetAdminPasswordDialog extends StatefulWidget {
  final ScreenTimeController controller;

  const _SetAdminPasswordDialog({required this.controller});

  @override
  State<_SetAdminPasswordDialog> createState() =>
      _SetAdminPasswordDialogState();
}

class _SetAdminPasswordDialogState extends State<_SetAdminPasswordDialog> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = S.of(context);
    final newPassword = _newController.text;
    if (newPassword.length < kAdminPasswordMinLength) {
      setState(() => _error = l10n.adminPasswordTooShort);
      return;
    }
    if (newPassword != _confirmController.text) {
      setState(() => _error = l10n.adminPasswordMismatch);
      return;
    }
    widget.controller.updateAdminPassword(newPassword);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isChange = widget.controller.hasAdminPassword;
    return AlertDialog(
      title: Text(
        isChange ? l10n.adminPasswordChangeTitle : l10n.adminPasswordSetTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.adminPasswordNewLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.adminPasswordConfirmLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bankCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
      ],
    );
  }
}
