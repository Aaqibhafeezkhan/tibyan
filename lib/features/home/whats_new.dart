import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';

/// The «what's new» notes: shown once after an update that brings them,
/// never on a first install (the reader is new to all of it), and from
/// the settings at any time. Bump [whatsNewId] when the list changes.
const whatsNewId = '2026-10-b';

/// Where the last notes seen are remembered.
const whatsNewSeenKey = 'app.whatsNewSeen';

typedef WhatsNewItem = ({IconData icon, String title, String body});

List<WhatsNewItem> whatsNewItems(AppLocalizations l) => [
  (icon: Icons.flag_outlined, title: l.newKhatmah, body: l.newKhatmahBody),
  (icon: Icons.mic_none, title: l.newTasmee, body: l.newTasmeeBody),
  (icon: Icons.timer_outlined, title: l.newSajdah, body: l.newSajdahBody),
  (
    icon: Icons.lightbulb_outline,
    title: l.newAssistant,
    body: l.newAssistantBody,
  ),
  (icon: Icons.fullscreen, title: l.newFocus, body: l.newFocusBody),
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          LookSheetHeader(title: l.whatsNewTitle, icon: Icons.auto_awesome),
          const SizedBox(height: 16),
          for (final item in whatsNewItems(l))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                      SizedBox.square(
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
          const SizedBox(height: 12),
          FilledButton(
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
