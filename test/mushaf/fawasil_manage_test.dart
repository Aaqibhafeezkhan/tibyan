import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/fawasil_manage.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// «الفواصل» in the index, the move dialog, the per-fasil look and the
/// sheet shown at the limit.
void main() {
  late UserDatabase db;
  late ProviderContainer c;
  BookmarkSetRow? opened;

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

  Future<int> add(String name, {int surah = 2, int ayah = 1}) =>
      db.addBookmarkSet(
        name: name,
        color: 0xFFB23A3A,
        surah: surah,
        ayah: ayah,
        page: 1,
      );

  /// [seed] fills the database before anything watches it.
  Future<void> pump(
    WidgetTester tester,
    Widget Function() body, {
    Future<void> Function()? seed,
  }) async {
    SharedPreferences.setMockInitialValues({'settings.fasilStyle': 'ribbon'});
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final sp = await SharedPreferences.getInstance();
    db = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    if (seed != null) await tester.runAsync(seed);
    c = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(sp),
        userDatabaseProvider.overrideWithValue(db),
        surahsProvider.overrideWith((ref) async => surahs),
        riwayaDataProvider.overrideWith((ref) async => null),
        packRootProvider.overrideWithValue(
          Directory.systemTemp.createTempSync('fawasil_packs'),
        ),
        // Page = surah * 10 + ayah, in the edition being read.
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('ar'),
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
          home: Scaffold(body: Builder(builder: (_) => body())),
        ),
      ),
    );
  }

  Future<List<BookmarkSetRow>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.watchBookmarkSets().first))!;

  testWidgets('the index lists each fasil with its place and page', (
    tester,
  ) async {
    await pump(
      tester,
      () => FawasilIndexTab(onOpen: (f) => opened = f),
      seed: () async {
        await add('الكهف', surah: 18, ayah: 1);
        await add('يس', surah: 36, ayah: 5);
      },
    );
    await idle(tester);
    expect(find.text('الكهف'), findsOneWidget);
    expect(find.text('يس'), findsOneWidget);
    // Its page in the edition being read, and a full label for readers.
    expect(
      find.bySemanticsLabel(RegExp('فاصلة يس، سورة ٣٦ الآية ٥، الصفحة ٣٦٥')),
      findsOneWidget,
    );
    await tester.tap(find.text('يس'));
    expect(opened?.name, 'يس');
  });

  testWidgets('delete from the index, then undo puts it back', (tester) async {
    late int id;
    await pump(
      tester,
      () => FawasilIndexTab(onOpen: (_) {}),
      seed: () async => id = await add('الكهف'),
    );
    await idle(tester);
    await tester.tap(find.byKey(ValueKey('fawasil-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await idle(tester);
    expect(await rows(tester), isEmpty);
    await tester.tap(find.text('تراجع'));
    await idle(tester);
    expect((await rows(tester)).single.id, id);
  });

  testWidgets('move to a surah and verse, a page, or the current place', (
    tester,
  ) async {
    late int id;
    await pump(
      tester,
      () => FawasilIndexTab(onOpen: (_) {}),
      seed: () async => id = await add('الكهف'),
    );
    await idle(tester);
    Future<void> openMove() async {
      await tester.tap(find.byKey(ValueKey('fawasil-menu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('انقل إلى…'));
      await tester.pumpAndSettle();
    }

    // The current reading place.
    await openMove();
    await tester.tap(find.byKey(const ValueKey('fasil-move-submit')));
    await idle(tester);
    var f = (await rows(tester)).single;
    expect((f.surah, f.ayah, f.page), (36, 1, 361));

    // A verse past the surah's end is refused; a good one is taken.
    await openMove();
    await tester.tap(find.byKey(const ValueKey('fasil-move-verse')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fasil-move-ayah')), '99');
    await tester.tap(find.byKey(const ValueKey('fasil-move-submit')));
    await idle(tester);
    expect(find.text('موضع غير صحيح'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('fasil-move-ayah')), '7');
    await tester.tap(find.byKey(const ValueKey('fasil-move-submit')));
    await idle(tester);
    f = (await rows(tester)).single;
    expect((f.surah, f.ayah, f.page), (36, 7, 367));
  });

  testWidgets('its own look, then «اتبع الإعداد الافتراضي»', (tester) async {
    late int id;
    await pump(
      tester,
      () => FawasilIndexTab(onOpen: (_) {}),
      seed: () async => id = await add('الكهف'),
    );
    await idle(tester);
    await tester.tap(find.byKey(ValueKey('fawasil-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('غيّر الشكل والخامة واللون'));
    await idle(tester);
    await tester.tap(find.byKey(const ValueKey('fasil-own-cloth-velvet')));
    await idle(tester);
    await tester.tap(find.byKey(const ValueKey('fasil-own-look-tab')));
    await idle(tester);
    var f = (await rows(tester)).single;
    expect((f.look, f.material), ('tab', 'velvet'));
    await tester.tap(find.byKey(const ValueKey('fasil-follow-default')));
    await idle(tester);
    f = (await rows(tester)).single;
    expect((f.look, f.material), (null, null));
  });

  testWidgets('at the limit: move one here or delete one; over it, told '
      'all are kept', (tester) async {
    await pump(
      tester,
      () => const SizedBox.expand(),
      seed: () async {
        for (var i = 0; i < maxFawasil; i++) {
          await add('f$i');
        }
      },
    );
    final ctx = tester.element(find.byType(SizedBox).last);
    final sheet = showFawasilLimit(ctx, here: (surah: 50, ayah: 3), page: 518);
    await idle(tester);
    expect(find.textContaining('٨'), findsWidgets);
    expect(find.byKey(const ValueKey('fasil-limit-delete-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fasil-limit-move-2')));
    await idle(tester);
    await sheet;
    final f = (await rows(tester)).firstWhere((r) => r.id == 2);
    expect((f.surah, f.ayah, f.page), (50, 3, 518));
  });
}
