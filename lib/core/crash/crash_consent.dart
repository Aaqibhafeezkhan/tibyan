import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../theme/interface_style.dart';
import '../ui/look_kit.dart';
import 'crash_reporting.dart';

/// The one-time question about crash reports: asked once on first launch,
/// and once for readers who had the app before it existed. The answer can
/// be changed later in the settings.
class CrashConsent {
  /// Where «asked» is remembered.
  static const askedKey = 'crash.consentAsked';

  /// Whether to ask now: the build can send reports, the reader was never
  /// asked, and has not already turned them on in the settings.
  static bool shouldAsk(SharedPreferences prefs, {required bool available}) =>
      available &&
      !(prefs.getBool(askedKey) ?? false) &&
      !(prefs.getBool('settings.crashReportsOptIn') ?? false);

  /// Records the answer: asked for good, and the setting follows it.
  static Future<void> answer(
    SharedPreferences prefs,
    SettingsController settings, {
    required bool agree,
  }) async {
    await prefs.setBool(askedKey, true);
    await settings.setCrashReportsOptIn(agree);
  }
}

/// Opens the question once, after the first frame of [context]. Skips
/// a frame where another sheet ([busy]) is opening; it is asked next time.
void maybeAskCrashConsent(
  BuildContext context,
  WidgetRef ref, {
  bool busy = false,
}) {
  final prefs = ref.read(sharedPreferencesProvider);
  if (busy ||
      !CrashConsent.shouldAsk(prefs, available: CrashReporting.isAvailable)) {
    return;
  }
  // Asked as soon as offered: closing the sheet counts as «no».
  prefs.setBool(CrashConsent.askedKey, true);
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    final agree = await showCrashConsent(
      context,
      suggestAgree: CrashReporting.isPrerelease,
    );
    await CrashConsent.answer(
      prefs,
      ref.read(settingsProvider.notifier),
      agree: agree ?? false,
    );
  });
}

/// The calm question itself. [suggestAgree] (TestFlight / beta builds)
/// makes «agree» the main, focused button.
Future<bool?> showCrashConsent(
  BuildContext context, {
  required bool suggestAgree,
}) => showModalBottomSheet<bool>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final size = Size.fromHeight(look.target);
    final agree = suggestAgree
        ? FilledButton(
            key: const Key('crashConsentAgree'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: look.control,
              foregroundColor: look.onControl,
              minimumSize: size,
            ),
            child: Text(l.crashConsentAgree),
          )
        : OutlinedButton(
            key: const Key('crashConsentAgree'),
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(minimumSize: size),
            child: Text(l.crashConsentAgree),
          );
    // Scrolls when large text makes it taller than the screen.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LookSheetHeader(
              title: l.crashConsentTitle,
              icon: Icons.health_and_safety_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              l.crashConsentBody,
              style: TextStyle(color: look.sub, height: 1.6),
            ),
            const SizedBox(height: 20),
            agree,
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('crashConsentDecline'),
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(minimumSize: size),
              child: Text(l.crashConsentDecline),
            ),
          ],
        ),
      ),
    );
  },
);
