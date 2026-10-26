import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/app.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final registry = await ThemeRegistry.load(rootBundle);
    final sp = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(sp),
      ],
    );
  }

  test(
    'defaults: follow the device motion, announce the verse number',
    () async {
      final c = await containerWith({});
      final s = c.read(settingsProvider);
      expect(s.forceReduceMotion, isFalse);
      expect(s.announceVerseNumber, isTrue);
    },
  );

  test('both switches are kept across launches', () async {
    final c = await containerWith({});
    await c.read(settingsProvider.notifier).setForceReduceMotion(true);
    await c.read(settingsProvider.notifier).setAnnounceVerseNumber(false);
    final sp = await SharedPreferences.getInstance();
    final again = await containerWith({
      for (final k in sp.getKeys()) k: sp.get(k)!,
    });
    expect(again.read(settingsProvider).forceReduceMotion, isTrue);
    expect(again.read(settingsProvider).announceVerseNumber, isFalse);
  });

  test('forced reduce motion turns animations off; off follows the device', () {
    const device = MediaQueryData();
    expect(
      appMediaQuery(
        device,
        elderly: false,
        reduceMotion: true,
      ).disableAnimations,
      isTrue,
    );
    expect(
      appMediaQuery(
        device,
        elderly: false,
        reduceMotion: false,
      ).disableAnimations,
      isFalse,
    );
    expect(
      appMediaQuery(
        device.copyWith(disableAnimations: true),
        elderly: false,
        reduceMotion: false,
      ).disableAnimations,
      isTrue,
    );
    // The text size is left alone outside elderly mode.
    expect(
      appMediaQuery(device, elderly: false, reduceMotion: true).textScaler,
      device.textScaler,
    );
  });

  test(
    'the accessibility section holds the three settings, found by search',
    () {
      final ids = [
        for (final g in SettingsSection.accessibility.groups)
          for (final e in g.entries) e.id,
      ];
      expect(ids, [
        'reduceMotion',
        'announceVerseNumber',
        'systemAccessibility',
      ]);
      expect(
        searchSettings('تقليل الحركة').map((h) => h.$2.id),
        contains('reduceMotion'),
      );
      expect(
        searchSettings('screen reader').map((h) => h.$2.id),
        contains('announceVerseNumber'),
      );
    },
  );
}
