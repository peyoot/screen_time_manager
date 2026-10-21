/// 许可与免责声明页。
///
/// 文案按语言维护在 l10n 的 `licenseBody` 中，以空行分段渲染；
/// 条款强调应用按"现状"提供，用户自行承担全部风险与责任。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 许可与免责声明页（命名避开 Flutter 自带的 `LicensePage`）。
class LicenseDisclaimerPage extends StatelessWidget {
  const LicenseDisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    // 空行分段：每个段落独立渲染，便于阅读长条款。
    final paragraphs = l10n.licenseBody
        .split('\n\n')
        .where((paragraph) => paragraph.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.licenseTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.licenseAgreeNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                paragraph,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
