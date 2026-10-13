import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';
import 'package:tibyan/features/settings/settings_screen.dart';
import 'package:tibyan/features/settings/settings_section_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The settings grid: eight tiles, each opening its section; the search
/// over every setting; and every setting reachable in its section.
void main() {
  late ContentDatabase db;
  late Directory root;
  late ThemeRegistry registry;
  setUpAll(() async {
    db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    root = Directory.systemTemp.createTempSync('settings');
    registry = await ThemeRegistry.load(rootBundle);
  });
  tearDownAll(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GoRouter> pump(
    WidgetTester tester, {
    String at = '/settings',
    Size size = const Size(420, 900),
    bool elderly = false,
    bool english = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'app.whatsNewSeen': 'all',
      'settings.elderlyMode': elderly,
    });
    final sp = await SharedPreferences.getInstance();
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(user.close));
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'section/:id',
              builder: (context, state) => SettingsSectionScreen(
                section: SettingsSection.values.byName(
                  state.pathParameters['id']!,
                ),
                focus: state.uri.queryParameters['focus'],
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDatabaseProvider.overrideWithValue(db),
          userDatabaseProvider.overrideWithValue(user),
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          packRootProvider.overrideWithValue(root),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(settingsProvider);
            return MaterialApp.router(
              routerConfig: router,
              locale: Locale(english ? 'en' : 'ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildTheme(
                style: registry.byId(registry.defaultStyleId),
                mode: ThemeModeId.light,
                uiFont: UiFont.changa,
                elderly: s.elderlyMode,
                interfaceStyle: s.interfaceStyle,
              ),
            );
          },
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  test('every setting has one id and one place', () {
    final ids = [for (final (_, e) in allSettings) e.id];
    expect(ids.toSet(), hasLength(ids.length));
    for (final s in SettingsSection.values) {
      expect(s.groups, isNotEmpty, reason: s.name);
    }
  });

  test('the assistant section draws one entry; its topics are found by '
      'search and open the topic', () {
    final drawn = [
      for (final g in SettingsSection.assistant.groups)
        for (final e in g.entries)
          if (e.link == null) e.id,
    ];
    expect(drawn, ['assistant']);
    final marks = searchSettings('علامات التجويد');
    expect(marks.first.$2.id, 'help.marks');
    expect(marks.first.$2.link, '/assistant/tajweed');
    expect(
      searchSettings('microphone').map((h) => h.$2.id),
      contains('help.faq-mic'),
    );
    expect(
      searchSettings('النسخ الاحتياطي').map((h) => h.$2.id),
      contains('help.backup'),
    );
  });

  test('«report a problem» lives in About, with the crash-reports switch', () {
    expect(searchSettings('إبلاغ').first.$2.id, 'reportProblem');
    expect(searchSettings('report problem').first.$2.id, 'reportProblem');
    final crash = searchSettings('crash').first;
    expect(crash.$1, SettingsSection.about);
    expect(crash.$2.link, '/settings/report');
    expect([
      for (final g in SettingsSection.storage.groups)
        for (final e in g.entries) e.id,
    ], isNot(contains('crashReports')));
  });

  test('search finds every setting by its Arabic and English titles', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final en = lookupAppLocalizations(const Locale('en'));
    for (final (_, e) in allSettings) {
      for (final title in [e.title(ar), e.title(en)]) {
        expect(
          searchSettings(title).map((h) => h.$2.id),
          contains(e.id),
          reason: '${e.id}: $title',
        );
      }
    }
    // Spelling is folded: no hamza, ta marbuta as ha.
    expect(searchSettings('اضاءه').map((h) => h.$2.id), contains('lightMode'));
    expect(searchSettings('reciter').first.$2.id, 'player');
    expect(searchSettings('zzzz'), isEmpty);
  });

  testWidgets('the grid: eight tiles, two columns on a phone', (tester) async {
    await pump(tester);
    for (final s in SettingsSection.values) {
      expect(
        find.byKey(ValueKey('settings-tile.${s.name}')),
        findsOneWidget,
        reason: s.name,
      );
    }
    final a = tester.getRect(
      find.byKey(const ValueKey('settings-tile.appearance')),
    );
    final b = tester.getRect(
      find.byKey(const ValueKey('settings-tile.mushaf')),
    );
    final c = tester.getRect(
      find.byKey(const ValueKey('settings-tile.listening')),
    );
    expect(a.top, b.top);
    expect(c.top, greaterThan(a.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a laptop gets four columns, two rows', (tester) async {
    await pump(tester, size: const Size(1440, 900));
    final first = tester.getRect(
      find.byKey(const ValueKey('settings-tile.appearance')),
    );
    final fourth = tester.getRect(
      find.byKey(const ValueKey('settings-tile.hifz')),
    );
    final fifth = tester.getRect(
      find.byKey(const ValueKey('settings-tile.khatma')),
    );
    expect(fourth.top, first.top);
    expect(fifth.top, greaterThan(first.bottom));
  });

  testWidgets('elderly mode: taller tiles, larger names', (tester) async {
    await pump(tester);
    final normal = tester.getSize(
      find.byKey(const ValueKey('settings-tile.appearance')),
    );
    final normalFont = tester
        .widget<Text>(find.text('المظهر'))
        .style!
        .fontSize!;
    await tester.pumpWidget(const SizedBox());
    await pump(tester, elderly: true);
    final big = tester.getSize(
      find.byKey(const ValueKey('settings-tile.appearance')),
    );
    expect(big.height, greaterThan(normal.height));
    expect(
      tester.widget<Text>(find.text('المظهر')).style!.fontSize,
      greaterThan(normalFont),
    );
  });

  testWidgets('a tile opens its section', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('settings-tile.listening')));
    await settle(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/settings/section/listening',
    );
    expect(find.text('شكل المشغل'), findsWidgets);
  });

  testWidgets('search: results, then the setting lit in its section', (
    tester,
  ) async {
    final router = await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'كبار السن',
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('settings-tile.mushaf')), findsNothing);
    final hit = find.byKey(const ValueKey('settings-hit.elderlyMode'));
    expect(hit, findsOneWidget);
    await tester.tap(hit);
    await settle(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/settings/section/appearance?focus=elderlyMode',
    );
    expect(find.text('وضع كبار السن'), findsWidgets);
  });

  testWidgets('search with no match says so', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'zzzz',
    );
    await settle(tester);
    expect(find.text('لا إعداد بهذا الاسم. جرّب كلمة أخرى.'), findsOneWidget);
  });

  for (final section in SettingsSection.values) {
    testWidgets('every setting of «${section.name}» is reachable', (
      tester,
    ) async {
      for (final g in section.groups) {
        for (final e in g.entries) {
          // Found by search only, and opened elsewhere.
          if (e.link != null) continue;
          await tester.pumpWidget(const SizedBox());
          await pump(
            tester,
            at: '${section.location}?focus=${e.id}',
            size: const Size(420, 1000),
          );
          final anchor = find.bySemanticsIdentifier('setting.${e.id}');
          expect(anchor, findsOneWidget, reason: e.id);
          // Scrolled into view.
          final r = tester.getRect(anchor);
          expect(r.top, lessThan(1000), reason: e.id);
          expect(r.bottom, greaterThan(0), reason: e.id);
          expect(tester.takeException(), isNull, reason: e.id);
        }
      }
    });
  }
}
