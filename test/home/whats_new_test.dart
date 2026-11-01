import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/l10n/app_localizations_ar.dart';
import 'package:tibyan/l10n/app_localizations_en.dart';

void main() {
  Future<SharedPreferences> prefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('an update shows the notes once', () async {
    final p = await prefs({'settings.onboardingDone': true});
    expect(shouldShowWhatsNew(p), isTrue);
    await markWhatsNewSeen(p);
    expect(shouldShowWhatsNew(p), isFalse);
  });

  test('a first install never shows them', () async {
    final p = await prefs({});
    expect(shouldShowWhatsNew(p), isFalse);
  });

  test('older notes seen: the new ones show', () async {
    final p = await prefs({
      'settings.onboardingDone': true,
      whatsNewSeenKey: 'older',
    });
    expect(shouldShowWhatsNew(p), isTrue);
  });

  test('readers who saw the previous notes see these once', () async {
    final p = await prefs({
      'settings.onboardingDone': true,
      whatsNewSeenKey: '2026-10-e',
    });
    expect(shouldShowWhatsNew(p), isTrue);
    await markWhatsNewSeen(p);
    expect(p.getString(whatsNewSeenKey), whatsNewId);
    expect(shouldShowWhatsNew(p), isFalse);
  });

  test('the notes cover builds 42, 41 and 40, newest first, in both '
      'languages', () {
    for (final l in [AppLocalizationsAr(), AppLocalizationsEn()]) {
      final groups = whatsNewGroups(l);
      expect([for (final g in groups) g.build], [42, 41, 40]);
      for (final g in groups) {
        expect(g.items, isNotEmpty);
        for (final i in g.items) {
          expect(i.title.trim(), isNotEmpty);
          expect(i.body.trim(), isNotEmpty);
        }
      }
    }
  });
}
