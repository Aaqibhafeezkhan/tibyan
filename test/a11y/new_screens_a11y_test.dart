import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/crash/crash_consent.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/fawasil_manage.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The newer screens and sheets (fawasil in the index, the move dialog,
/// a fasil's own look, the limit sheet, what's new, crash consent), in
/// Arabic and English: labelled controls with 48 dp targets, and nothing
/// overflows at twice the text size. The khatma and group khatma screens
/// are in screen_guidelines_test.dart.
void main() {
  late UserDatabase db;
  final surahs = [
    for (var i = 1; i <= 114; i++)
      SurahRow(
        id: i,
        nameAr: 'سورة $i',
        nameEn: 'Surah $i',
        meaningEn: '',
        revelation: 'meccan',
        revelationOrder: i,
        ayahCount: 10,
        startPage: i,
        startPage1405: i,
        sourceId: i,
        startPageShamarly: i,
      ),
  ];

  Future<void> idle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  /// A host with three fawasil (ids 1..3); [body] is its screen.
  Future<void> pump(
    WidgetTester tester,
    Widget body, {
    required String locale,
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({'settings.fasilStyle': 'ribbon'});
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final sp = await SharedPreferences.getInstance();
    db = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(() async {
      for (final (i, name) in ['الكهف', 'يس', 'Al-Mulk'].indexed) {
        await db.addBookmarkSet(
          name: name,
          color: 0xFFB23A3A,
          surah: 18 + i,
          ayah: 1,
          page: 1,
        );
      }
    });
    final c = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(sp),
        userDatabaseProvider.overrideWithValue(db),
        surahsProvider.overrideWith((ref) async => surahs),
        riwayaDataProvider.overrideWith((ref) async => null),
        packRootProvider.overrideWithValue(
          Directory.systemTemp.createTempSync('a11y_packs'),
        ),
        versePageProvider.overrideWith((ref, v) async => v.$1 * 10 + v.$2),
        readingPositionProvider.overrideWith(
          (ref) => Stream.value(
            ReadingPositionRow(
              id: 1,
              edition: 'v1441',
              view: 'page',
              surah: 36,
              ayah: 1,
              page: 440,
              updatedAt: DateTime(2026),
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId('zakhrafa'),
            mode: ThemeModeId.light,
            uiFont: UiFont.plex,
            interfaceStyle: defaultInterfaceStyle,
          ),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: child!,
          ),
          home: Scaffold(body: LookTheme(child: body)),
        ),
      ),
    );
    await idle(tester);
  }

  BuildContext host(WidgetTester tester) =>
      tester.element(find.byKey(const Key('a11y-host')));

  const blank = SizedBox.expand(key: Key('a11y-host'));

  // Each case: its screen, then what opens on it.
  final cases = <String, (Widget, Future<void> Function(WidgetTester))>{
    'fawasil index': (FawasilIndexTab(onOpen: (_) {}), (_) async {}),
    'move dialog': (
      FawasilIndexTab(onOpen: (_) {}),
      (tester) async {
        await tester.tap(find.byKey(const ValueKey('fawasil-menu-1')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(host2(tester));
        await tester.tap(find.text(l.fasilMoveTo));
        await idle(tester);
        await tester.tap(find.byKey(const ValueKey('fasil-move-verse')));
        await idle(tester);
      },
    ),
    'fasil look': (
      FawasilIndexTab(onOpen: (_) {}),
      (tester) async {
        await tester.tap(find.byKey(const ValueKey('fawasil-menu-1')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(host2(tester));
        await tester.tap(find.text(l.fasilChangeStyle));
        await idle(tester);
      },
    ),
    'limit sheet': (
      blank,
      (tester) async {
        showFawasilLimit(host(tester), here: (surah: 50, ayah: 3), page: 518);
        await idle(tester);
      },
    ),
    'what\'s new': (
      blank,
      (tester) async {
        showWhatsNew(host(tester));
        await idle(tester);
      },
    ),
    'crash consent': (
      blank,
      (tester) async {
        showCrashConsent(host(tester), suggestAgree: false);
        await idle(tester);
      },
    ),
  };

  for (final MapEntry(key: name, value: (screen, open)) in cases.entries) {
    for (final locale in ['ar', 'en']) {
      testWidgets('$name ($locale): labelled, 48 dp targets', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, screen, locale: locale);
        await open(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.pumpWidget(const SizedBox());
        handle.dispose();
      });

      testWidgets('$name ($locale): no overflow at 200% text', (tester) async {
        await pump(tester, screen, locale: locale, scale: 2);
        await open(tester);
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: error is FlutterError ? error.toStringDeep() : '$error',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('what\'s new: build headings are headers, each note one '
      'node, read in order', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, blank, locale: 'ar');
    showWhatsNew(host(tester));
    await idle(tester);
    final l = AppLocalizations.of(host(tester));
    expect(
      tester.getSemantics(find.text(l.whatsNewBuild('٤٢'))),
      matchesSemantics(label: l.whatsNewBuild('٤٢'), isHeader: true),
    );
    final first = tester.getSemantics(find.text(l.wn42Fawasil));
    expect(first.label, contains(l.wn42FawasilBody));
    handle.dispose();
  });
}

/// Any element under the app, for its localizations.
BuildContext host2(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);
