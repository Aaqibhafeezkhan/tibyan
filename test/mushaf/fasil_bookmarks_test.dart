import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/backup/backup.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_sheet.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The fawasil drawn as ribbons and tabs: where each look puts them (top,
/// side, focus mode, a spread's spine), the folded ones and their taps,
/// the first-time chooser, and readers who already had fawasil keeping the
/// tinted verse.
void main() {
  const hifz = FasilMark(
    id: 1,
    name: 'حفظ',
    color: Color(0xFFB23A3A),
    page: 50,
  );
  const review = FasilMark(
    id: 2,
    name: 'مراجعة',
    color: Color(0xFF1D2F55),
    page: 51,
  );
  const ribbon = FasilLook(style: FasilStyle.ribbon, motion: false);
  const tab = FasilLook(style: FasilStyle.tab, motion: false);

  Widget app(Widget child, {Size size = const Size(400, 700)}) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: SizedBox.fromSize(size: size, child: child),
    ),
  );

  /// Lets the database answer, then settles.
  Future<void> idle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

  group('on the page', () {
    testWidgets('the tinted look draws nothing over the page', (tester) async {
      await tester.pumpWidget(
        app(
          const FasilPageLayer(
            marks: [hifz],
            look: FasilLook(style: FasilStyle.tint),
            outerRight: true,
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(FasilRibbon), findsNothing);
      expect(find.byType(FasilTab), findsNothing);
    });

    testWidgets('a ribbon hangs from the top on the outer side', (
      tester,
    ) async {
      for (final outerRight in [true, false]) {
        await tester.pumpWidget(
          app(
            FasilPageLayer(
              key: ValueKey(outerRight),
              marks: const [hifz],
              look: ribbon,
              outerRight: outerRight,
              child: const SizedBox.expand(),
            ),
          ),
        );
        final page = rectOf(tester, find.byType(FasilPageLayer));
        final r = rectOf(tester, find.byType(FasilRibbon));
        expect(r.top, page.top);
        if (outerRight) {
          expect(r.right, greaterThan(page.right - 60));
        } else {
          expect(r.left, lessThan(page.left + 60));
        }
        // Shorter than the page: it hangs over its top part.
        expect(r.height, lessThan(page.height * .6));
        expect(find.text('حفظ'), findsOneWidget);
      }
    });

    testWidgets('a tab rises from the top; on the side it is turned', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const FasilPageLayer(
            marks: [hifz],
            look: tab,
            outerRight: true,
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(FasilTab), findsOneWidget);
      expect(find.byType(RotatedBox), findsNothing);
      expect(
        rectOf(tester, find.byType(FasilTab)).top,
        rectOf(tester, find.byType(FasilPageLayer)).top,
      );

      await tester.pumpWidget(
        app(
          const FasilPageLayer(
            key: ValueKey('side'),
            marks: [hifz],
            look: FasilLook(
              style: FasilStyle.tab,
              place: FasilPlace.side,
              motion: false,
            ),
            outerRight: true,
            child: SizedBox.expand(),
          ),
        ),
      );
      final page = rectOf(tester, find.byType(FasilPageLayer));
      final turned = rectOf(tester, find.byType(RotatedBox));
      expect(turned.right, closeTo(page.right, 1));
      expect(turned.top, greaterThan(page.top));
    });

    testWidgets('focus mode: a short ribbon for either look', (tester) async {
      for (final look in [ribbon, tab]) {
        await tester.pumpWidget(
          app(
            FasilPageLayer(
              key: ValueKey(look.style),
              marks: const [hifz],
              look: look,
              outerRight: true,
              focus: true,
              child: const SizedBox.expand(),
            ),
          ),
        );
        expect(find.byType(FasilTab), findsNothing);
        final r = rectOf(tester, find.byType(FasilRibbon));
        expect(r.height, lessThan(700 * .2));
      }
    });

    testWidgets('a spread keeps its ribbons in the spine, tabs at its head', (
      tester,
    ) async {
      const size = Size(1000, 700);
      await tester.pumpWidget(
        app(
          const FasilSpineLayer(
            right: [hifz],
            left: [review],
            look: ribbon,
            child: SizedBox.expand(),
          ),
          size: size,
        ),
      );
      final spread = rectOf(tester, find.byType(FasilSpineLayer));
      for (final r in tester.widgetList(find.byType(FasilRibbon))) {
        final box = tester.getRect(find.byWidget(r));
        expect((box.center.dx - spread.center.dx).abs(), lessThan(30));
        // Down the whole gutter.
        expect(box.height, greaterThan(spread.height * .9));
        expect(box.bottom, lessThanOrEqualTo(spread.bottom + 1));
      }
      expect(find.byType(FasilRibbon), findsNWidgets(2));

      await tester.pumpWidget(
        app(
          const FasilSpineLayer(
            key: ValueKey('tabs'),
            right: [hifz],
            left: [review],
            look: tab,
            child: SizedBox.expand(),
          ),
          size: size,
        ),
      );
      final onRight = tester.getRect(find.byKey(const ValueKey('fasil-1')));
      final onLeft = tester.getRect(find.byKey(const ValueKey('fasil-2')));
      expect(onRight.left, greaterThanOrEqualTo(spread.center.dx));
      expect(onLeft.right, lessThanOrEqualTo(spread.center.dx));
      expect(onRight.top, spread.top);
    });

    testWidgets('a long press on a bookmark opens its actions', (tester) async {
      FasilMark? pressed;
      await tester.pumpWidget(
        app(
          FasilPageLayer(
            marks: const [hifz],
            look: ribbon,
            outerRight: true,
            onLongPress: (m) => pressed = m,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.longPress(find.byType(FasilRibbon));
      expect(pressed, hifz);
    });
  });

  group('folded', () {
    testWidgets('a tap goes to its page, a long press opens its actions', (
      tester,
    ) async {
      FasilMark? tapped, pressed;
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: FoldedFawasil(
              marks: const [hifz, review],
              look: ribbon,
              onTap: (m) => tapped = m,
              onLongPress: (m) => pressed = m,
              semanticLabel: (m) => '${m.name} ${m.page}',
            ),
          ),
        ),
      );
      expect(find.byType(FasilRibbon), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('folded-2')));
      expect(tapped, review);
      await tester.longPress(find.byKey(const ValueKey('folded-1')));
      expect(pressed, hifz);
      // Folded stubs carry no label and stay short.
      expect(find.text('حفظ'), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('folded-1'))).height, 48);
    });

    testWidgets('elderly mode: targets of 56 at least', (tester) async {
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: FoldedFawasil(
              marks: const [hifz],
              look: const FasilLook(
                style: FasilStyle.tab,
                elderly: true,
                motion: false,
              ),
              onTap: (_) {},
              onLongPress: (_) {},
              semanticLabel: (m) => m.name,
            ),
          ),
        ),
      );
      final s = tester.getSize(find.byKey(const ValueKey('folded-1')));
      expect(s.height, greaterThanOrEqualTo(elderlyTarget));
    });
  });

  group('entrance', () {
    testWidgets('a just-placed ribbon drops in, once', (tester) async {
      final mark = FasilMark(
        id: 9,
        name: 'تلاوة',
        color: const Color(0xFF2E7D5B),
        page: 50,
        placedAt: DateTime.now(),
      );
      armFasilEntrance();
      await tester.pumpWidget(
        app(
          FasilPageLayer(
            marks: [mark],
            look: const FasilLook(style: FasilStyle.ribbon),
            outerRight: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final start = tester.getRect(find.byType(FasilRibbon));
      await tester.pump(const Duration(milliseconds: 650));
      final end = tester.getRect(find.byType(FasilRibbon));
      expect(start.top, lessThan(end.top));
      expect(fasilJustPlaced.value, isNull);
    });

    testWidgets('with less motion it is simply there', (tester) async {
      final mark = FasilMark(
        id: 9,
        name: 'تلاوة',
        color: const Color(0xFF2E7D5B),
        page: 50,
        placedAt: DateTime.now(),
      );
      armFasilEntrance();
      await tester.pumpWidget(
        app(
          FasilPageLayer(
            marks: [mark],
            look: const FasilLook(style: FasilStyle.ribbon, motion: false),
            outerRight: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FasilPageLayer),
          matching: find.byType(FractionalTranslation),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
      fasilJustPlaced.value = null;
    });
  });

  group('settings', () {
    Future<ProviderContainer> containerWith(
      WidgetTester tester,
      Map<String, Object> prefs,
    ) async {
      SharedPreferences.setMockInitialValues(prefs);
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      final sp = await SharedPreferences.getInstance();
      final user = UserDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(user.close));
      final c = ProviderContainer(
        overrides: [
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          userDatabaseProvider.overrideWithValue(user),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('a reader who never chose keeps the tinted verse', (
      tester,
    ) async {
      final c = await containerWith(tester, {'settings.markerTint': 1});
      final s = c.read(settingsProvider);
      expect(s.fasilStyle, isNull);
      expect(s.effectiveFasilStyle, FasilStyle.tint);
      expect(s.fasilPlace, FasilPlace.top);
      expect(s.fasilMaterial, FasilMaterial.silk);
      expect(s.fasilTassel, isTrue);
    });

    testWidgets('the choices are kept, and carried by a backup', (
      tester,
    ) async {
      final c = await containerWith(tester, {});
      final ctrl = c.read(settingsProvider.notifier);
      await ctrl.setFasilStyle(FasilStyle.tab);
      await ctrl.setFasilPlace(FasilPlace.side);
      await ctrl.setFasilMaterial(FasilMaterial.velvet);
      await ctrl.setFasilTassel(false);
      final sp = await SharedPreferences.getInstance();
      final keys = sp.getKeys().where((k) => k.contains('fasil')).toSet();
      expect(keys, {
        'settings.fasilStyle',
        'settings.fasilPlace',
        'settings.fasilMaterial',
        'settings.fasilTassel',
      });
      expect(keys.every(Backup.carries), isTrue);
      final again = await containerWith(tester, {
        for (final k in sp.getKeys()) k: sp.get(k)!,
      });
      final s = again.read(settingsProvider);
      expect(s.fasilStyle, FasilStyle.tab);
      expect(s.fasilPlace, FasilPlace.side);
      expect(s.fasilMaterial, FasilMaterial.velvet);
      expect(s.fasilTassel, isFalse);
    });

    testWidgets('the settings search finds «شكل الفاصلة»', (tester) async {
      final entries = [
        for (final groups in settingsCatalog.values)
          for (final g in groups) ...g.entries,
      ];
      final e = entries.singleWhere((e) => e.id == 'fasilStyle');
      for (final word in ['فاصل', 'شريطة', 'لسان', 'ribbon']) {
        expect(e.keywords, contains(word));
      }
    });

    Future<BuildContext> themed(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      late BuildContext ctx;
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
              style: c.read(themeRegistryProvider).byId('zakhrafa'),
              mode: ThemeModeId.light,
              uiFont: UiFont.plex,
              interfaceStyle: defaultInterfaceStyle,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ctx = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      return ctx;
    }

    testWidgets('the first fasil asks the look, with three previews', (
      tester,
    ) async {
      final c = await containerWith(tester, {});
      final ctx = await themed(tester, c);
      FasilStyle? got;
      final ref = ProviderScope.containerOf(ctx);
      final done = ensureFasilStyleFor(
        ctx,
        ref,
        hasFawasil: false,
      ).then((s) => got = s);
      await tester.pumpAndSettle();
      expect(find.byType(FasilStyleChooser), findsOneWidget);
      expect(find.byType(FasilPreview), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('fasil-choose-ribbon')));
      await tester.pumpAndSettle();
      await done;
      expect(got, FasilStyle.ribbon);
      expect(c.read(settingsProvider).fasilStyle, FasilStyle.ribbon);
    });

    testWidgets('a reader with fawasil is asked on their next fasil; '
        'closing keeps the tint', (tester) async {
      final c = await containerWith(tester, {});
      final ctx = await themed(tester, c);
      final ref = ProviderScope.containerOf(ctx);
      FasilStyle? got;
      final done = ensureFasilStyleFor(
        ctx,
        ref,
        hasFawasil: true,
      ).then((s) => got = s);
      await tester.pumpAndSettle();
      expect(find.byType(FasilStyleChooser), findsOneWidget);
      Navigator.of(tester.element(find.byType(FasilStyleChooser))).pop();
      await tester.pumpAndSettle();
      await done;
      expect(got, FasilStyle.tint);
      expect(c.read(settingsProvider).fasilStyle, FasilStyle.tint);
    });

    testWidgets('a tap on a verse number places the reading fasil in the '
        'look chosen then', (tester) async {
      final c = await containerWith(tester, {});
      final ctx = await themed(tester, c);
      final ref = ProviderScope.containerOf(ctx);
      bool? placed;
      final done = placeFixedFasil(
        ctx,
        ref,
        MarkKind.reading,
        name: 'قراءة',
        surah: 2,
        ayah: 255,
        page: 42,
      ).then((p) => placed = p);
      await idle(tester);
      expect(find.byType(FasilStyleChooser), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fasil-choose-tab')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => done);
      expect(placed, isTrue);
      expect(c.read(settingsProvider).fasilStyle, FasilStyle.tab);
      final db = c.read(userDatabaseProvider);
      final rows = (await tester.runAsync(() => db.watchBookmarkSets().first))!;
      expect(rows.single.kind, 'reading');
      expect(rows.single.color, MarkKind.reading.color);

      // Placed again (a look chosen now): moved, not asked, still one.
      final again = placeFixedFasil(
        ctx,
        ref,
        MarkKind.reading,
        name: 'قراءة',
        surah: 3,
        ayah: 1,
        page: 50,
      );
      await idle(tester);
      expect(find.byType(FasilStyleChooser), findsNothing);
      expect(await tester.runAsync(() => again), isTrue);
      final moved = (await tester.runAsync(
        () => db.watchBookmarkSets().first,
      ))!;
      expect(moved.single.ayah, 1);
      expect(moved.single.page, 50);
    });

    testWidgets('closing the first chooser places nothing', (tester) async {
      final c = await containerWith(tester, {});
      final ctx = await themed(tester, c);
      final ref = ProviderScope.containerOf(ctx);
      final done = placeFixedFasil(
        ctx,
        ref,
        MarkKind.hifz,
        name: 'حفظ',
        surah: 2,
        ayah: 1,
        page: 2,
      );
      await idle(tester);
      Navigator.of(tester.element(find.byType(FasilStyleChooser))).pop();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => done), isFalse);
      final rows = (await tester.runAsync(
        () => c.read(userDatabaseProvider).watchBookmarkSets().first,
      ))!;
      expect(rows, isEmpty);
      expect(c.read(settingsProvider).fasilStyle, isNull);
    });

    testWidgets('fixed and named fawasil share one rendering path', (
      tester,
    ) async {
      final c = await containerWith(tester, {});
      final db = c.read(userDatabaseProvider);
      final rows = (await tester.runAsync(() async {
        for (final (k, n) in [
          (MarkKind.reading, 'قراءة'),
          (MarkKind.review, 'مراجعة'),
          (MarkKind.hifz, 'حفظ'),
          (MarkKind.tadabbur, 'تدبر'),
        ]) {
          await db.setMark(k, name: n, surah: 3, ayah: 1, page: 50);
        }
        await db.addBookmarkSet(
          name: 'ورد',
          color: 0xFF1D2F55,
          surah: 3,
          ayah: 2,
          page: 50,
        );
        return db.watchBookmarkSets().first;
      }))!;
      // Tinted: every fasil tints its verse, none is drawn.
      expect(
        fasilTints(rows, const FasilLook(style: FasilStyle.tint), (m) => m.id),
        hasLength(5),
      );
      expect(
        fasilMarksOf(rows, const FasilLook(style: FasilStyle.tint), (m) => 0),
        isEmpty,
      );
      for (final look in [ribbon, tab]) {
        expect(fasilTints(rows, look, (m) => m.id), isEmpty);
        final marks = fasilMarksOf(rows, look, (m) => m.page);
        expect(marks, hasLength(5));
        // The fixed ones keep their colours.
        expect(
          marks.map((m) => m.color.toARGB32()),
          containsAll([for (final k in MarkKind.values) k.color]),
        );
        await tester.pumpWidget(
          app(
            FasilPageLayer(
              key: ValueKey(look.style),
              marks: marks.take(3).toList(),
              look: look,
              outerRight: true,
              child: const SizedBox.expand(),
            ),
            size: const Size(800, 900),
          ),
        );
        if (look == tab) {
          expect(find.byType(FasilTab), findsNWidgets(3));
        } else {
          expect(find.byType(FasilRibbon), findsNWidgets(3));
        }
        // Each one carries its name.
        for (final n in ['قراءة', 'مراجعة', 'حفظ']) {
          expect(find.text(n), findsOneWidget);
        }
      }
    });
  });

  testWidgets('the name dialog suggests names', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final result = showDialog<String>(
      context: ctx,
      builder: (_) => const FasilNameDialog(),
    );
    await tester.pumpAndSettle();
    for (final s in ['حفظ', 'تلاوة', 'مراجعة']) {
      expect(find.widgetWithText(ActionChip, s), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ActionChip, 'تلاوة'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(await result, 'تلاوة');
  });

  test('new fawasil take the card palette as tabs', () {
    expect(nextFasilColor(FasilStyle.tab, 0), fasilCardColors[0]);
    expect(nextFasilColor(FasilStyle.ribbon, 1), fasilColors[1]);
    expect(fasilLabelColor(Color(fasilCardColors[2])), isNot(Colors.white));
    expect(fasilLabelColor(Color(fasilCardColors[0])), Colors.white);
  });
}
