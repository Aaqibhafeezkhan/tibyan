import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
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
import 'package:tibyan/features/khatma/domain/khatmah.dart' show EntryPoint;
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/mushaf_screen.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';

import '../testing/bundled_pages.dart';

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
    root = Directory.systemTemp.createTempSync('indexjump');
    final dir = Directory(p.join(root.path, 'packs', 'pages-hafs-1441-v1'))
      ..createSync(recursive: true);
    final zip = bundledPagesArchive();
    for (final name in ['603.svg.xz', '604.svg.xz']) {
      final entry = zip.findFile(name)!;
      File(p.join(dir.path, entry.name)).writeAsBytesSync(entry.content);
    }
    File(p.join(dir.path, '.installed')).writeAsStringSync('test');
  });
  tearDownAll(() => db.close());

  Future<ProviderContainer> start(WidgetTester tester) async {
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
    });
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final flags = (await tester.runAsync(() => FeatureFlags.load(rootBundle)))!;
    final prefs = await SharedPreferences.getInstance();
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(user.close));
    // Wide enough for the tools' bar in the test font.
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        themeRegistryProvider.overrideWithValue(registry),
        featureFlagsProvider.overrideWithValue(flags),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
    container.read(appRouterProvider).go('/mushaf?page=604');
    return container;
  }

  Future<void> settle(WidgetTester tester, [Finder? until]) async {
    for (var i = 0; i < 40; i++) {
      if (until != null && until.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool showing(int page) => find
      .byWidgetPredicate((w) => w is MushafPage && w.page == page)
      .evaluate()
      .isNotEmpty;

  test('the page view keeps its identity across page jumps', () {
    final a = mushafSessionOf(Uri.parse(mushafLocation(10)));
    final b = mushafSessionOf(
      Uri.parse(mushafLocation(400, entry: EntryPoint.home)),
    );
    expect(a, b);
    expect(a, mushafSessionOf(Uri.parse('/mushaf/index?tab=juz')));
    // A verse to select, memorization, listening: opened anew.
    expect(
      mushafSessionOf(Uri.parse(mushafLocation(10, surah: 2, ayah: 5))),
      isNot(a),
    );
    expect(mushafSessionOf(Uri.parse('/mushaf?page=10&memorize=1')), isNot(a));
    expect(mushafSessionOf(Uri.parse('/mushaf?listen=1')), isNot(a));
  });

  testWidgets('a jump from the index turns the open page view', (tester) async {
    final container = await start(tester);
    await settle(tester, find.byType(MushafPage));
    expect(showing(604), isTrue);
    final before = tester.state(find.byType(MushafScreen));
    final router = container.read(appRouterProvider);

    // The index over the page, then a surah in it.
    unawaited(router.push('/mushaf/index'));
    await settle(tester);
    router.go(mushafLocation(603));
    await settle(
      tester,
      find.byWidgetPredicate((w) => w is MushafPage && w.page == 603),
    );
    expect(showing(603), isTrue);
    // The same reader, its pager turned: not built again.
    expect(tester.state(find.byType(MushafScreen)), same(before));
    // The index is gone; nothing left to go back to on the page view.
    expect(router.canPop(), isFalse);

    // The same page again (a new visit) from the home screen's card.
    router.go(mushafLocation(604, entry: EntryPoint.home));
    await settle(
      tester,
      find.byWidgetPredicate((w) => w is MushafPage && w.page == 604),
    );
    expect(showing(604), isTrue);
    expect(tester.state(find.byType(MushafScreen)), same(before));

    // A verse link (a verse to select) opens the page view anew.
    router.go(mushafLocation(603, surah: 113, ayah: 1));
    await settle(tester);
    expect(tester.state(find.byType(MushafScreen)), isNot(same(before)));
    expect(showing(603), isTrue);
  });
}
