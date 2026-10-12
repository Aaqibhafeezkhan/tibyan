import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<GoRouter> pump(WidgetTester tester, {required bool reduce}) async {
    SharedPreferences.setMockInitialValues({'settings.onboardingDone': true});
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
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
}
