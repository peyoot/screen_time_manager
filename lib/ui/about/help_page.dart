/// 帮助与使用说明页：主要功能、使用步骤与数据说明。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 帮助页。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final paragraphs = l10n.helpBody
        .split('\n\n')
        .where((paragraph) => paragraph.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
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
