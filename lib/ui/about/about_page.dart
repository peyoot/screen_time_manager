/// 关于页：版本号、发行版本（Free / Pro）、题库配额与许可/帮助入口。
library;

import 'package:flutter/material.dart';

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
    final limits = AppInfo.limits;
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
          const SizedBox(height: 10),
          Center(
            child: Chip(
              avatar: Icon(
                AppInfo.isPro
                    ? Icons.workspace_premium
                    : Icons.card_giftcard,
                size: 18,
              ),
              label: Text(
                AppInfo.isPro ? l10n.aboutEditionPro : l10n.aboutEditionFree,
              ),
            ),
          ),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.aboutLimitsTitle),
            subtitle: Text(
              l10n.aboutLimitsText(
                limits.maxGroups,
                limits.maxQuestionsPerGroup,
              ),
            ),
          ),
          if (!AppInfo.isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                l10n.aboutProHint(
                  AppLimits.pro.maxGroups,
                  AppLimits.pro.maxQuestionsPerGroup,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.aboutCopyright,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
