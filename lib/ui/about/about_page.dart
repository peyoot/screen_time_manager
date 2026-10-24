/// 关于页：版本号、Pro 标识，以及许可 / 帮助 / 建议加群入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_info.dart';
import '../../l10n/app_localizations.dart';
import 'help_page.dart';
import 'license_page.dart';

/// 关于页。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Icon(
            Icons.hourglass_top,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              l10n.aboutVersion(AppInfo.version),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          // 仅 Pro 版显示标识，用于和免费版区分。
          if (AppInfo.isPro) ...[
            const SizedBox(height: 10),
            Center(
              child: Chip(
                avatar: const Icon(Icons.workspace_premium, size: 18),
                label: Text(l10n.aboutEditionPro),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.aboutDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicense),
            subtitle: Text(l10n.aboutLicenseSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LicenseDisclaimerPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.aboutHelp),
            subtitle: Text(l10n.aboutHelpSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: Text(l10n.aboutFeedback),
            subtitle: Text(l10n.aboutFeedbackSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFeedbackDialog(context),
          ),
        ],
      ),
    );
  }
}

/// 建议 / 加群对话框：展示微信号并支持一键复制。
Future<void> _showFeedbackDialog(BuildContext context) {
  final l10n = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.feedbackTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.feedbackIntro),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.feedbackWechatLabel,
                          style: theme.textTheme.labelSmall,
                        ),
                        SelectableText(
                          l10n.feedbackWechatId,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.feedbackCopy,
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: l10n.feedbackWechatId),
                      );
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(l10n.feedbackCopied)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.feedbackGroupHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.feedbackClose),
          ),
        ],
      );
    },
  );
}
