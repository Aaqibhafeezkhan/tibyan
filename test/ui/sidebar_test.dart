import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/l10n/app_localizations.dart';

void main() {
  late ThemeRegistry registry;
  setUpAll(() async => registry = await ThemeRegistry.load(rootBundle));

  Widget screen(String name) => LookScaffold(body: Center(child: Text(name)));

  Future<SharedPreferences> pump(
    WidgetTester tester, {
    double width = 1400,
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen('home')),
        GoRoute(path: '/search', builder: (_, _) => screen('search')),
        GoRoute(path: '/settings', builder: (_, _) => screen('settings')),
        // The mushaf draws its own full-width frame, without the sidebar.
        GoRoute(
          path: '/mushaf',
          builder: (_, _) =>
              LookScaffold(rail: false, body: const Text('mushaf')),
          routes: [GoRoute(path: 'index', builder: (_, _) => screen('index'))],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: ThemeModeId.light,
            uiFont: UiFont.plex,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return sp;
  }

  testWidgets('headings and all 11 destinations render', (tester) async {
    await pump(tester);
    for (final heading in ['القراءة', 'الاستماع', 'الورد والحفظ']) {
      expect(find.text(heading), findsWidgets);
    }
    for (final item in RailItem.values) {
      expect(find.byKey(ValueKey('rail-${item.name}')), findsOneWidget);
    }
    for (final label in [
      'الرئيسية',
      'الفهرس',
      'التسميع',
      'المسبحة',
      'الإعدادات',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a destination navigates', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rail-search')));
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rail-contents')));
    await tester.pumpAndSettle();
    expect(find.text('index'), findsOneWidget);
  });

  testWidgets('collapse shows icons only and is remembered', (tester) async {
    final sp = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('الفهرس'), findsNothing);
    expect(find.text('القراءة'), findsNothing);
    expect(find.byKey(const ValueKey('rail-contents')), findsOneWidget);
    expect(find.byTooltip('الفهرس'), findsOneWidget);
    expect(sp.getBool('ui.sidebarCollapsed'), isTrue);
  });

  testWidgets('a remembered fold starts folded', (tester) async {
    await pump(tester, prefs: {'ui.sidebarCollapsed': true});
    expect(find.text('الفهرس'), findsNothing);
    expect(find.byTooltip('الفهرس'), findsOneWidget);
  });

  testWidgets('a narrow window folds to icons, no toggle', (tester) async {
    await pump(tester, width: 950);
    expect(find.text('الفهرس'), findsNothing);
    expect(find.byKey(const ValueKey('rail-contents')), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-toggle')), findsNothing);
  });

  testWidgets('no sidebar on the mushaf', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rail-mushaf')));
    await tester.pumpAndSettle();
    expect(find.text('mushaf'), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-home')), findsNothing);
  });

  test('routes map to their destination', () {
    expect(railItemFor('/'), RailItem.home);
    expect(railItemFor('/mushaf/tafsir'), RailItem.tafsir);
    expect(railItemFor('/khatma/new'), RailItem.khatma);
    expect(railItemFor('/mushaf'), isNull);
  });
}
