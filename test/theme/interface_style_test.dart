import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/contrast.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/surah_name.dart';
import 'package:tibyan/features/hifz/hifz_providers.dart';
import 'package:tibyan/features/home/home_screen.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/index_screen.dart';
import 'package:tibyan/features/settings/settings_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// «شكل الواجهة»: the three interface styles, their contrast, the live
/// switch in settings, and each screen in each style.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    root = Directory.systemTemp.createTempSync('looks');
    registry = await ThemeRegistry.load(rootBundle);
  });
  tearDownAll(() => db.close());

  test('text reaches 4.5:1 (7:1 in elderly mode) in every style', () {
    final failures = <String>[];
    for (final style in InterfaceStyle.values) {
      for (final night in [false, true]) {
        for (final elderly in [false, true]) {
          final l = UiLook.of(style, night: night, elderly: elderly);
          final min = elderly ? 7.0 : 4.5;
          for (final (ground, gname) in [
            (l.bg, 'bg'),
            (l.surface, 'surface'),
            (l.row, 'row'),
          ]) {
            for (final (fg, fname) in [
              (l.ink, 'ink'),
              (l.sub, 'sub'),
              (l.goldText, 'goldText'),
              (l.accent2, 'accent2'),
            ]) {
              final r = contrastRatio(fg, ground);
              if (r < min) {
                failures.add(
                  '${style.name}/${night ? 'night' : 'light'}'
                  '${elderly ? '/elderly' : ''}: $fname on $gname '
                  '${r.toStringAsFixed(2)}',
                );
              }
            }
          }
          if (contrastRatio(l.onControl, l.control) < 4.5) {
            failures.add('${style.name}/$night: on control');
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('«هندسي» is the default and the choice is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(sp),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).interfaceStyle, InterfaceStyle.handasi);
    await c
        .read(settingsProvider.notifier)
        .setInterfaceStyle(InterfaceStyle.makhtuta);
    expect(sp.getString('settings.interfaceStyle'), 'makhtuta');
    final again = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(sp),
      ],
    );
    addTearDown(again.dispose);
    expect(
      again.read(settingsProvider).interfaceStyle,
      InterfaceStyle.makhtuta,
    );
  });

  test('surah names: one KFGQPC glyph per surah, U+F100 to U+F171', () {
    expect(surahNameGlyphs(1).codeUnitAt(0), 0xF100);
    expect(surahNameGlyphs(114).codeUnitAt(0), 0xF171);
    expect({for (var s = 1; s <= 114; s++) surahNameGlyphs(s)}, hasLength(114));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  /// [home] under the app's theme, rebuilt from the settings so a change
  /// of style shows at once (as in TibyanApp).
  Future<SharedPreferences> pump(
    WidgetTester tester,
    Widget home, {
    InterfaceStyle? style,
    bool english = false,
    bool night = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'app.whatsNewSeen': 'all',
      'settings.interfaceStyle': ?style?.name,
    });
    final sp = await SharedPreferences.getInstance();
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(user.close));
    await tester.binding.setSurfaceSize(Size(english ? 560 : 420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDatabaseProvider.overrideWithValue(db),
          userDatabaseProvider.overrideWithValue(user),
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          packRootProvider.overrideWithValue(root),
          readingPositionProvider.overrideWith((ref) => Stream.value(null)),
          khatmaStatusProvider.overrideWith((ref) async => null),
          srsItemsProvider.overrideWith((ref) => Stream.value(const [])),
          journeyProvider.overrideWithValue((memorized: 0, mastered: 0)),
          bookmarkSetsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(settingsProvider);
            return MaterialApp(
              locale: Locale(english ? 'en' : 'ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildTheme(
                style: registry.byId(registry.defaultStyleId),
                mode: night ? ThemeModeId.night : ThemeModeId.light,
                uiFont: UiFont.changa,
                interfaceStyle: s.interfaceStyle,
              ),
              home: home,
            );
          },
        ),
      ),
    );
    await settle(tester);
    return sp;
  }

  UiLook lookOf(WidgetTester tester, Finder f) =>
      Theme.of(tester.element(f)).extension<UiLook>()!;

  testWidgets('settings: picking a style applies it at once and keeps it', (
    tester,
  ) async {
    final sp = await pump(tester, const SettingsScreen());
    expect(
      lookOf(tester, find.byType(SettingsScreen)).style,
      InterfaceStyle.handasi,
    );
    final layli = find.byKey(const ValueKey('interfaceStyle.layli'));
    expect(
      tester.getSemantics(layli),
      isSemantics(
        label: 'ليلي ذهبي',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    await tester.tap(layli);
    await settle(tester);
    // The theme animates to the new look.
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      lookOf(tester, find.byType(SettingsScreen)).style,
      InterfaceStyle.layli,
    );
    expect(sp.getString('settings.interfaceStyle'), 'layli');
    expect(tester.takeException(), isNull);
  });

  for (final style in InterfaceStyle.values) {
    for (final night in [false, true]) {
      final tag = '${style.name} ${night ? 'night' : 'light'}';
      testWidgets('home in $tag', (tester) async {
        await pump(tester, const HomeScreen(), style: style, night: night);
        expect(find.text('الأقسام'), findsOneWidget);
        expect(lookOf(tester, find.byType(HomeScreen)).style, style);
        expect(tester.takeException(), isNull);
      });
      testWidgets('index in $tag', (tester) async {
        await pump(tester, const IndexScreen(), style: style, night: night);
        // The first rows: separators and surah titles in the KFGQPC font.
        expect(find.bySemanticsLabel(RegExp('^سورة الفاتحة')), findsOneWidget);
        expect(find.text(surahNameGlyphs(1)), findsOneWidget);
        expect(find.text('الجزء ١'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets('settings in $tag', (tester) async {
        await pump(tester, const SettingsScreen(), style: style, night: night);
        expect(find.text('شكل الواجهة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Arrows: disclosure chevrons and back arrows are the mirroring icons
  // (chevron_right, arrow_back), drawn in the locale's direction, so they
  // point left in Arabic and right in English; a fixed left or right
  // chevron would point inward in one of them.
  for (final english in [false, true]) {
    testWidgets('arrows follow the reading direction '
        '(${english ? 'English' : 'Arabic'})', (tester) async {
      for (final screen in const [SettingsScreen(), IndexScreen()]) {
        await pump(tester, screen, english: english);
        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        final arrows = [
          for (final i in icons)
            if (i.icon == Icons.chevron_right ||
                i.icon == Icons.chevron_left ||
                i.icon == Icons.arrow_back ||
                i.icon == Icons.arrow_forward)
              i,
        ];
        // Settings: disclosure chevrons; index: the back arrow is shown
        // only with a route to go back to.
        if (screen is SettingsScreen) expect(arrows, isNotEmpty);
        for (final i in arrows) {
          expect(i.icon, isNot(Icons.chevron_left));
          expect(i.icon!.matchTextDirection, isTrue);
        }
        final dir = english ? TextDirection.ltr : TextDirection.rtl;
        for (final e in find.byIcon(Icons.chevron_right).evaluate()) {
          expect(Directionality.of(e), dir);
        }
      }
    });
  }
}
