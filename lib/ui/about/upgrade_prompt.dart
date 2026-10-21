/// 配额超限时的升级提示对话框。
library;

import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../l10n/app_localizations.dart';
import 'about_page.dart';

/// 弹出"升级到 Pro 版"提示。
///
/// [exception] 携带超限类型与当前版本上限；"了解 Pro 版"跳转关于页
/// （展示版本、配额与帮助入口）。
Future<void> showUpgradePrompt(
  BuildContext context,
  LimitExceededException exception,
) {
  final l10n = S.of(context);
  final isGroups = exception.kind == LimitKind.groups;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        isGroups ? l10n.limitGroupsTitle : l10n.limitQuestionsTitle,
      ),
      content: Text(
        isGroups
            ? l10n.limitGroupsMessage(
                exception.limit,
                AppLimits.pro.maxGroups,
              )
            : l10n.limitQuestionsMessage(
                exception.limit,
                AppLimits.pro.maxQuestionsPerGroup,
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.limitLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutPage()),
            );
          },
          child: Text(l10n.limitUpgrade),
        ),
      ],
    ),
  );
}
