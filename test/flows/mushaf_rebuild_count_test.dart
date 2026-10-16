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
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/mushaf_screen.dart';
import 'package:tibyan/features/mushaf/presentation/mushaf_page_recitation.dart';

import '../testing/bundled_pages.dart';

/// Listening to al-Falaq; [at] moves it, as the player does.
class SteppedRecitation extends RecitationController {
  @override
  RecitationState build() => const RecitationState(
    active: true,
    playing: true,
    surah: 113,
    ayah: 1,
    word: 1,
    timed: true,
  );

  void at(int ayah, int word) => state = RecitationState(
    active: true,
    playing: true,
    surah: 113,
    ayah: ayah,
    word: word,
    timed: true,
  );

  @override
  Future<VerseJump> jumpTo(int surah, int ayah, {int? word}) async =>
      VerseJump.jumped;
}

/// The mushaf screen is not built again for every word of a recitation,
/// nor for a setting it does not show: only the small layer that draws
/// the verse and word being recited is.
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
    root = Directory.systemTemp.createTempSync('tapjump');
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

  Future<ProviderContainer> start(
    WidgetTester tester,
    SteppedRecitation recitation,
  ) async {
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
        recitationProvider.overrideWith(() => recitation),
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

  testWidgets('a recitation moving word by word rebuilds only its layer', (
    tester,
  ) async {
    final recitation = SteppedRecitation();
    final container = await start(tester, recitation);
    await settle(tester);

    MushafScreen.debugBuildCount = 0;
    RecitedPage.debugBuildCount = 0;
    // Twelve words over three verses of al-Falaq, on the page shown.
    var steps = 0;
    for (final (ayah, words) in [(1, 4), (2, 4), (3, 4)]) {
      for (var w = 1; w <= words; w++) {
        recitation.at(ayah, w);
        await tester.pump();
        steps++;
      }
    }
    final screen = MushafScreen.debugBuildCount;
    final layer = RecitedPage.debugBuildCount;
    // ignore: avoid_print
    print('recitation: $steps steps, screen builds $screen, layer $layer');
    expect(screen, 0);
    expect(layer, greaterThanOrEqualTo(steps));

    // A setting the page does not show.
    MushafScreen.debugBuildCount = 0;
    await container.read(settingsProvider.notifier).setCrashReportsOptIn(true);
    await tester.pump();
    // ignore: avoid_print
    print('unrelated setting: screen builds ${MushafScreen.debugBuildCount}');
    expect(MushafScreen.debugBuildCount, 0);
  });
}
