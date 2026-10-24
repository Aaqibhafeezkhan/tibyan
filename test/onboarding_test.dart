import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/app.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/flags/feature_flags.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/onboarding/onboarding_frame.dart';

void main() {
  // Some steps keep a spinner or a download going: pump a while instead
  // of waiting for stillness.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> launch(
    WidgetTester tester, [
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final (registry, flags, sp) = (await tester.runAsync(
      () async => (
        await ThemeRegistry.load(rootBundle),
        await FeatureFlags.load(rootBundle),
        await SharedPreferences.getInstance(),
      ),
    ))!;
    final user = UserDatabase(NativeDatabase.memory());
    final content = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    addTearDown(
      () => tester.runAsync(() async {
        await user.close();
        await content.close();
      }),
    );
    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(user),
        contentDatabaseProvider.overrideWithValue(content),
        themeRegistryProvider.overrideWithValue(registry),
        featureFlagsProvider.overrideWithValue(flags),
        sharedPreferencesProvider.overrideWithValue(sp),
        // No edition is on this fresh device.
        packRootProvider.overrideWithValue(
          Directory.systemTemp.createTempSync('packs'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TibyanApp()),
    );
    // Past the splash screen.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    return container;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await settle(tester);
  }

  String location(WidgetTester tester) => GoRouterLocation.of(tester);

  testWidgets('fresh install: six steps, then the app', (tester) async {
    final container = await launch(tester);

    // Defaults: the «هندسي» interface, the plain page, light, new edition.
    final settings = container.read(settingsProvider);
    expect(settings.interfaceStyle, InterfaceStyle.handasi);
    expect(settings.styleId, 'simple');
    expect(settings.mode, ModeSetting.light);
    expect(settings.edition, MushafEdition.madina1441);

    // Step 1: language, titled in both languages.
    expect(location(tester), OnboardingStep.language.location);
    expect(find.textContaining('Choose your language'), findsOneWidget);
    expect(find.bySemanticsLabel('الخطوة ١ من ٦'), findsOneWidget);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(container.read(settingsProvider).language, LanguageSetting.en);
    expect(find.text('Skip all'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await settle(tester);
    await next(tester);

    // Step 2: interface style and light, elderly mode.
    expect(location(tester), OnboardingStep.style.location);
    expect(find.text('تخطَّ الكل'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('interfaceStyle.layli')));
    await settle(tester);
    expect(
      container.read(settingsProvider).interfaceStyle,
      InterfaceStyle.layli,
    );
    await next(tester);

    // Step 3: the page look.
    expect(location(tester), OnboardingStep.page.location);
    await next(tester);

    // Step 4: the edition.
    expect(location(tester), OnboardingStep.edition.location);
    final old = find.text('مصحف المدينة: الطبعة القديمة');
    await tester.ensureVisible(old);
    await settle(tester);
    await tester.tap(old);
    await settle(tester);
    expect(container.read(settingsProvider).edition, MushafEdition.madina1405);
    await next(tester);

    // Step 5: a reciter, skipped; streaming needs no download.
    expect(location(tester), OnboardingStep.reciter.location);
    expect(find.text('تقدر تسمع أي شيخ أونلاين من غير تحميل'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip-step')));
    await settle(tester);

    // Step 6: the recitation model, skipped: the first run is over.
    expect(location(tester), OnboardingStep.tasmee.location);
    expect(
      find.text('المصدر والرخصة في «عن المصحف» › المصادر'),
      findsOneWidget,
    );
    expect(container.read(settingsProvider).onboardingDone, isFalse);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip-step')));
    await settle(tester);
    expect(container.read(settingsProvider).onboardingDone, isTrue);
    // No «what's new» for a new reader.
    expect(
      container.read(sharedPreferencesProvider).getString(whatsNewSeenKey),
      whatsNewId,
    );
    expect(location(tester), isNot(startsWith('/onboarding')));
  });

  testWidgets('«skip all» from the first step keeps the defaults', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip-all')));
    await settle(tester);
    final s = container.read(settingsProvider);
    expect(s.onboardingDone, isTrue);
    expect(s.interfaceStyle, InterfaceStyle.handasi);
    expect(s.styleId, 'simple');
    expect(s.edition, MushafEdition.madina1441);
    expect(location(tester), isNot(startsWith('/onboarding')));
  });

  testWidgets('an upgrading reader who finished it never sees it again', (
    tester,
  ) async {
    await launch(tester, {
      'settings.onboardingDone': true,
      whatsNewSeenKey: whatsNewId,
    });
    expect(location(tester), '/');
    expect(find.byType(OnboardingFrame), findsNothing);
  });

  testWidgets('a reader from before the flag (has seen «what\'s new») is '
      'not walked through it', (tester) async {
    final container = await launch(tester, {whatsNewSeenKey: 'older'});
    expect(container.read(settingsProvider).onboardingDone, isTrue);
    expect(find.byType(OnboardingFrame), findsNothing);
  });
}

/// The router's current location, read from the app's [MaterialApp].
abstract final class GoRouterLocation {
  static String of(WidgetTester tester) {
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    final config = app.routerConfig! as dynamic;
    final String at = config.routerDelegate.currentConfiguration.uri.toString();
    return at;
  }
}
