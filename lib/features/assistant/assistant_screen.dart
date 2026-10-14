import 'package:flutter/material.dart';

import '../../core/ui/look_kit.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'help_topics.dart';
import '../../core/ui/responsive.dart';

/// Where the Assistant opens.
const assistantLocation = '/assistant';

/// The Assistant's icon, the same on every way in (home, the reader's
/// menus).
const assistantIcon = Icons.lightbulb_outline;

/// «المساعد»: the help centre: using the app, the tajweed and dabt marks,
/// and answers to common problems, one card per topic.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final lang = l.localeName;
    String groupName(HelpGroup g) => switch (g) {
      HelpGroup.usage => l.helpGroupUsage,
      HelpGroup.marks => l.helpGroupMarks,
      HelpGroup.faq => l.helpGroupFaq,
    };
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.assistantTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ContentWidth.narrow,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Text(
                          l.assistantIntro,
                          style: TextStyle(color: t.muted, height: 1.6),
                        ),
                      ),
                      for (final g in HelpGroup.values) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(
                            groupName(g),
                            style: TextStyle(
                              color: t.goldText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final topic in helpTopics)
                          if (topic.group == g)
                            _HelperCard(
                              key: ValueKey('help-topic.${topic.id}'),
                              icon: topic.icon,
                              title: topic.titleIn(lang),
                              onTap: () => context.push(topic.route),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One topic: its icon on a soft disc and its name.
class _HelperCard extends StatelessWidget {
  const _HelperCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens.colors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.goldText.withValues(alpha: 0.12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: t.goldText, size: 26),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// One help topic: its steps, numbered.
class HelpTopicScreen extends StatelessWidget {
  const HelpTopicScreen({super.key, required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final ar = l.localeName == 'ar';
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: topic.titleIn(l.localeName)),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ContentWidth.narrow,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final (i, step) in topic.steps.indexed)
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: t.goldText.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                ar
                                    ? String.fromCharCodes(
                                        '${i + 1}'.codeUnits.map(
                                          (c) => c - 0x30 + 0x660,
                                        ),
                                      )
                                    : '${i + 1}',
                                style: TextStyle(color: t.goldText),
                              ),
                            ),
                            title: Text(
                              ar ? step.ar : step.en,
                              style: TextStyle(color: t.ink, height: 1.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
