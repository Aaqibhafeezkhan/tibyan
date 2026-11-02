import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/splash/splash_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The splash: the logo at the native launch screen's size, a moment of
/// light along it, home within a second; still with reduced motion.
void main() {
  late ThemeRegistry registry;
  setUpAll(() async => registry = await ThemeRegistry.load(rootBundle));

  late SharedPreferences sp;

  Future<GoRouter> pump(
    WidgetTester tester, {
    required bool reduce,
    DateTime? now,
    String? shownDay,
    bool onboarded = true,
    bool target = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': onboarded,
      'settings.splashShownDay': ?shownDay,
    });
    sp = await SharedPreferences.getInstance();
    final at = now ?? DateTime(2026, 11, 2, 9);
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => SplashScreen(now: () => at),
        ),
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          if (target)
            launchTargetProvider.overrideWithValue(ValueNotifier(true)),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(
              style: registry.byId(registry.defaultStyleId),
              mode: ThemeModeId.light,
              uiFont: UiFont.changa,
            ),
          ),
        ),
      ),
    );
    return router;
  }

  Finder shimmer() => find.ancestor(
    of: find.byType(TibyanWordmark),
    matching: find.byType(ShaderMask),
  );

  testWidgets('a light passes along the logo, then home within a second', (
    tester,
  ) async {
    await pump(tester, reduce: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(shimmer(), findsOneWidget);
    final logo = tester.getSize(find.byType(TibyanWordmark));
    expect(logo.height, splashLogoHeight);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reduced motion: still, and home all the same', (tester) async {
    await pump(tester, reduce: true);
    await tester.pump();
    expect(shimmer(), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
  });

  group('once a day', () {
    Future<void> home(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    }

    testWidgets('first launch of the day plays it and notes the day', (
      tester,
    ) async {
      await pump(tester, reduce: false, shownDay: '2026-11-01');
      await tester.pump(const Duration(milliseconds: 300));
      expect(shimmer(), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(sp.getString('settings.splashShownDay'), '2026-11-02');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a later launch the same day goes straight home', (
      tester,
    ) async {
      await pump(
        tester,
        reduce: false,
        shownDay: '2026-11-02',
        now: DateTime(2026, 11, 2, 23, 59),
      );
      expect(shimmer(), findsNothing);
      await home(tester);
    });

    testWidgets('past midnight it plays again', (tester) async {
      await pump(
        tester,
        reduce: false,
        shownDay: '2026-11-02',
        now: DateTime(2026, 11, 3, 0, 1),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(shimmer(), findsOneWidget);
      expect(sp.getString('settings.splashShownDay'), '2026-11-03');
    });

    testWidgets('a link, shortcut, notification or widget launch skips it', (
      tester,
    ) async {
      await pump(tester, reduce: false, target: true);
      expect(shimmer(), findsNothing);
      await home(tester);
      // Not counted as the day's splash.
      expect(sp.getString('settings.splashShownDay'), isNull);
    });

    testWidgets('a link arriving while it plays cuts it short', (tester) async {
      await pump(tester, reduce: false);
      await tester.pump(const Duration(milliseconds: 200));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(SplashScreen)),
      );
      c.read(launchTargetProvider).value = true;
      await home(tester);
    });

    testWidgets('before the first-run setup it always plays', (tester) async {
      await pump(
        tester,
        reduce: false,
        onboarded: false,
        shownDay: '2026-11-02',
        target: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(shimmer(), findsOneWidget);
    });

    testWidgets('reduced motion: unchanged, still every launch', (
      tester,
    ) async {
      await pump(tester, reduce: true, shownDay: '2026-11-02');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('home'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
