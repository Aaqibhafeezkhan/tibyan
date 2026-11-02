import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/app.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/flags/feature_flags.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/illuminated_frame.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';

import '../testing/bundled_pages.dart';

/// The soft keyboard rising over the mushaf (the go-to-page dialog's
/// field) must not move, resize, lay out again or re-bake the page.
void main() {
  late ContentDatabase db;
  late Directory root;
  setUpAll(() {
    db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    root = Directory.systemTemp.createTempSync('kbd');
    final dir = Directory(p.join(root.path, 'packs', 'pages-hafs-1441-v1'))
      ..createSync(recursive: true);
    final zip = bundledPagesArchive();
    for (final entry in zip.files) {
      File(p.join(dir.path, entry.name)).writeAsBytesSync(entry.content);
    }
    File(p.join(dir.path, '.installed')).writeAsStringSync('test');
  });
  tearDownAll(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    Size size,
    int page, {
    Map<String, Object> prefs = const {},
  }) async {
    for (final m in ['toggle', 'isEnabled']) {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.$m',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
          m == 'isEnabled' ? false : null,
        ]),
      );
    }
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'settings.language': 'ar',
      whatsNewSeenKey: whatsNewId,
      ...prefs,
    });
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final flags = (await tester.runAsync(() => FeatureFlags.load(rootBundle)))!;
    final sp = await SharedPreferences.getInstance();
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(user.close));
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        featureFlagsProvider.overrideWithValue(flags),
        sharedPreferencesProvider.overrideWithValue(sp),
        contentDatabaseProvider.overrideWithValue(db),
        userDatabaseProvider.overrideWithValue(user),
        packRootProvider.overrideWithValue(root),
        readingPositionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TibyanApp()),
    );
    await tester.pump(const Duration(seconds: 2));
    container.read(appRouterProvider).go('/mushaf?page=$page');
    await settle(tester);
    return container;
  }

  List<Rect> pages(WidgetTester tester) => [
    for (final e in find.byType(MushafPage).evaluate())
      if ((e.renderObject! as RenderBox).hasSize)
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
            (e.renderObject! as RenderBox).size,
  ];

  Future<void> keyboardOver(WidgetTester tester, Size size) async {
    await open(tester, size, 50);
    final before = pages(tester);
    expect(before, isNotEmpty);
    // The page number's own tap opens the dialog.
    tester
        .widget<IlluminatedFrame>(find.byType(IlluminatedFrame).first)
        .onPageTap!();
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    final layouts = MushafPage.debugLayouts;
    final bakes = MushafPage.debugBakes;

    // The keyboard rises, in steps as it animates.
    // About a phone keyboard's height; less of a short sideways window.
    final keyboard = (size.height * 0.4).roundToDouble().clamp(0.0, 320.0);
    for (var h = 40.0; h <= keyboard; h += 40) {
      tester.view.viewInsets = FakeViewPadding(bottom: h);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester);
    expect(pages(tester), before, reason: 'the page moved or resized');
    expect(MushafPage.debugLayouts, layouts, reason: 'the page laid out');
    expect(MushafPage.debugBakes, bakes, reason: 'the page was re-baked');
    // The dialog itself still lifts its field above the keyboard.
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(size.height - keyboard));

    // And falls.
    tester.view.resetViewInsets();
    await settle(tester);
    expect(pages(tester), before);
    expect(MushafPage.debugLayouts, layouts);
    expect(MushafPage.debugBakes, bakes);
  }

  testWidgets('phone upright', (tester) async {
    await keyboardOver(tester, const Size(430, 932));
  });

  testWidgets('phone sideways', (tester) async {
    await keyboardOver(tester, const Size(932, 430));
  });

  testWidgets('tablet sideways: the two-page spread', (tester) async {
    await keyboardOver(tester, const Size(1366, 1024));
  });
}
