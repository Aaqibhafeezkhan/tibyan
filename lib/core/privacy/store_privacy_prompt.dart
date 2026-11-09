import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../platform/app_store.dart';
import '../settings/settings_controller.dart';
import '../theme/interface_style.dart';
import '../ui/look_kit.dart';

/// Whether this build asks the reader to read the privacy policy on first
/// launch: the Huawei build only (AppGallery review rule 7.5). Overridden
/// in tests.
final storePrivacyPromptProvider = Provider<bool>((ref) => isHuaweiBuild);

/// The privacy policy page, in the reader's language.
Uri privacyPolicyUrl(Locale locale) => Uri.parse(
  locale.languageCode == 'ar'
      ? 'https://altibyan.app/privacy'
      : 'https://altibyan.app/privacy/en',
);

/// The one-time privacy notice: shown until the reader presses «موافق».
class StorePrivacyPrompt {
  /// Where the acceptance is remembered.
  static const acceptedKey = 'privacy.storePromptAccepted';

  static bool shouldShow(SharedPreferences prefs, {required bool enabled}) =>
      enabled && !(prefs.getBool(acceptedKey) ?? false);

  static Future<void> accept(SharedPreferences prefs) =>
      prefs.setBool(acceptedKey, true);

  /// Open now: not asked twice while it is on screen.
  static bool _open = false;
}

/// Whether the notice is about to open or open now, so other first-run
/// sheets wait for the next time.
bool storePrivacyPending(WidgetRef ref) => StorePrivacyPrompt.shouldShow(
  ref.read(sharedPreferencesProvider),
  enabled: ref.read(storePrivacyPromptProvider),
);

/// Opens the notice after the first frame of [context] when this build asks
/// for it and the reader has not accepted it yet.
void maybeShowStorePrivacy(BuildContext context, WidgetRef ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  if (StorePrivacyPrompt._open ||
      !StorePrivacyPrompt.shouldShow(
        prefs,
        enabled: ref.read(storePrivacyPromptProvider),
      )) {
    return;
  }
  StorePrivacyPrompt._open = true;
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) {
      StorePrivacyPrompt._open = false;
      return;
    }
    final accepted = await showStorePrivacy(context);
    StorePrivacyPrompt._open = false;
    if (accepted == true) {
      await StorePrivacyPrompt.accept(prefs);
    } else {
      await SystemNavigator.pop();
    }
  });
}

/// The notice itself. Returns true on «موافق», false on «خروج». It cannot
/// be closed by a tap outside or the back button.
Future<bool?> showStorePrivacy(BuildContext context) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final size = Size.fromHeight(look.target);
    final url = privacyPolicyUrl(Localizations.localeOf(context));
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('storePrivacyDialog'),
        title: LookSheetHeader(
          title: l.storePrivacyTitle,
          icon: Icons.privacy_tip_outlined,
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.storePrivacyBody,
              style: TextStyle(color: look.sub, height: 1.6),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('storePrivacyRead'),
              onPressed: () =>
                  launchUrl(url, mode: LaunchMode.externalApplication),
              style: TextButton.styleFrom(minimumSize: Size(48, look.target)),
              icon: const Icon(Icons.open_in_new),
              label: Text(l.storePrivacyRead),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('storePrivacyAccept'),
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: look.control,
                foregroundColor: look.onControl,
                minimumSize: size,
              ),
              child: Text(l.storePrivacyAccept),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('storePrivacyExit'),
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(minimumSize: size),
              child: Text(l.storePrivacyExit),
            ),
          ],
        ),
      ),
    );
  },
);
