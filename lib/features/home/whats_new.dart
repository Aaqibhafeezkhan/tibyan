import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/ui/look_kit.dart';
import '../../core/ui/meta_separator.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../../l10n/app_localizations.dart';

/// The «what's new» notes: shown once after an update that brings them,
/// never on a first install (the reader is new to all of it), and from
/// the settings at any time. Bump [whatsNewId] when the list changes.
const whatsNewId = 'build-42b';

/// Where the last notes seen are remembered.
const whatsNewSeenKey = 'app.whatsNewSeen';

typedef WhatsNewItem = ({IconData icon, String title, String body});

/// The notes of one build, newest first.
typedef WhatsNewGroup = ({int build, List<WhatsNewItem> items});

/// What shipped in the recent builds (from the changelog), newest first.
List<WhatsNewGroup> whatsNewGroups(AppLocalizations l) => [
  (
    build: 42,
    items: [
      (
        icon: Icons.bookmark_outline,
        title: l.wn42Fawasil,
        body: l.wn42FawasilBody,
      ),
      (
        icon: Icons.list_alt_outlined,
        title: l.wn42Index,
        body: l.wn42IndexBody,
      ),
      (
        icon: Icons.bookmarks_outlined,
        title: l.wn42Ribbons,
        body: l.wn42RibbonsBody,
      ),
      (
        icon: Icons.dark_mode_outlined,
        title: l.wn42Night,
        body: l.wn42NightBody,
      ),
      (icon: Icons.notifications_none, title: l.wn42Kahf, body: l.wn42KahfBody),
      (
        icon: Icons.keyboard_voice_outlined,
        title: l.wn42Voice,
        body: l.wn42VoiceBody,
      ),
      (
        icon: Icons.lock_clock_outlined,
        title: l.wn42Live,
        body: l.wn42LiveBody,
      ),
      (
        icon: Icons.desktop_windows_outlined,
        title: l.wn42Desktop,
        body: l.wn42DesktopBody,
      ),
      (icon: Icons.speed_outlined, title: l.wn42Speed, body: l.wn42SpeedBody),
      (
        icon: Icons.health_and_safety_outlined,
        title: l.wn42Crash,
        body: l.wn42CrashBody,
      ),
    ],
  ),
  (
    build: 41,
    items: [
      (
        icon: Icons.visibility_off_outlined,
        title: l.wn41Hifz,
        body: l.wn41HifzBody,
      ),
      (icon: Icons.groups_outlined, title: l.wn41Group, body: l.wn41GroupBody),
      (
        icon: Icons.insights_outlined,
        title: l.wn41Report,
        body: l.wn41ReportBody,
      ),
      (icon: Icons.sync, title: l.wn41Sync, body: l.wn41SyncBody),
      (icon: Icons.watch_outlined, title: l.wn41Watch, body: l.wn41WatchBody),
      (icon: Icons.movie_outlined, title: l.wn41Video, body: l.wn41VideoBody),
      (icon: Icons.accessibility_new, title: l.wn41A11y, body: l.wn41A11yBody),
    ],
  ),
  (
    build: 40,
    items: [
      (
        icon: Icons.touch_app_outlined,
        title: l.wn40Tasbih,
        body: l.wn40TasbihBody,
      ),
    ],
  ),
];

/// Whether the notes should open now: the reader has used the app before
/// (onboarding done) and has not seen these notes.
bool shouldShowWhatsNew(SharedPreferences prefs) =>
    (prefs.getBool('settings.onboardingDone') ?? false) &&
    prefs.getString(whatsNewSeenKey) != whatsNewId;

/// Marks the notes as seen (also on a first install, so they never show
/// for what the reader meets anyway).
Future<void> markWhatsNewSeen(SharedPreferences prefs) =>
    prefs.setString(whatsNewSeenKey, whatsNewId);

/// Opens the notes once per update, after the first frame of [context].
void maybeShowWhatsNew(BuildContext context, WidgetRef ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  if (!shouldShowWhatsNew(prefs)) return;
  // Seen as soon as offered: it never opens twice.
  markWhatsNewSeen(prefs);
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) showWhatsNew(context);
  });
}

Future<void> showWhatsNew(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => ListView(
        key: const Key('whatsNewList'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          LookSheetHeader(title: l.whatsNewTitle, icon: Icons.auto_awesome),
          const SizedBox(height: 8),
          Text(l.whatsNewIntro, style: TextStyle(color: look.sub, height: 1.5)),
          for (final group in whatsNewGroups(l)) ...[
            _BuildHeader(label: l.whatsNewBuild(digits(group.build))),
            for (final item in group.items) _WhatsNewCard(item: item),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('whatsNewDone'),
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: look.control,
              foregroundColor: look.onControl,
              minimumSize: Size.fromHeight(look.target),
            ),
            child: Text(l.whatsNewDone),
          ),
        ],
      ),
    );
  },
);

/// A build's heading between gold lines, with the metadata star on each
/// side: «─ ✶ التحديث ٤٢ ✶ ─».
class _BuildHeader extends StatelessWidget {
  const _BuildHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final line = Expanded(
      child: Divider(color: look.gold.withValues(alpha: .45), thickness: 1),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            line,
            const MetaSeparator(),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: look.goldText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const MetaSeparator(),
            line,
          ],
        ),
      ),
    );
  }
}

class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard({required this.item});
  final WhatsNewItem item;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              look.control.withValues(alpha: .05),
              look.surface,
            ),
            borderRadius: BorderRadius.circular(look.isMakhtuta ? 4 : 14),
            border: Border.all(color: look.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 40,
                    child: CustomPaint(
                      painter: StarPainter(
                        look.control.withValues(alpha: .10),
                        look.isHandasi ? look.control : look.gold,
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: look.isLayli ? look.goldText : look.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: look.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(color: look.sub, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
