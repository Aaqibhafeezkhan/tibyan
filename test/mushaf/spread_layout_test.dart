import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';

import '../testing/bundled_pages.dart';

/// Which pages the mushaf screen lays out, and where, on tablets held
/// sideways, desktop windows and phones held sideways. With
/// RENDER_SPREADS=1 it also writes each layout into `build/spreads/`.
void main() {
  final render = Platform.environment['RENDER_SPREADS'] == '1';
  late ContentDatabase db;
  late Directory root;
  setUpAll(() {
    db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    root = Directory.systemTemp.createTempSync('spreads');
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
    if (render) {
      await tester.runAsync(() async {
        final manifest = jsonDecode(
          await rootBundle.loadString('FontManifest.json'),
        ) as List<dynamic>;
        for (final f in manifest.cast<Map<String, dynamic>>()) {
          final loader = FontLoader(f['family'] as String);
          for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
            loader.addFont(
              rootBundle.load(Uri.decodeFull(a['asset'] as String)),
            );
          }
          await loader.load();
        }
      });
    }
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

  Future<void> shot(WidgetTester tester, String name) async {
    if (!render) return;
    final boundary = tester.binding.rootElement!.renderObject!.debugLayer!;
    final image = await tester.runAsync(() async {
      final scene = (boundary as OffsetLayer).toImage(
        Offset.zero & tester.view.physicalSize,
      );
      final img = await scene;
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    });
    Directory('build/spreads').createSync(recursive: true);
    File('build/spreads/$name.png').writeAsBytesSync(image!);
  }

  /// The pages on screen, by their left edge, left to right.
  List<(int, Rect)> pagesShown(WidgetTester tester) {
    final screen = Offset.zero & tester.view.physicalSize;
    final found = <(int, Rect)>[];
    for (final e in find.byType(MushafPage).evaluate()) {
      final box = e.renderObject! as RenderBox;
      if (!box.hasSize) continue;
      final r = box.localToGlobal(Offset.zero) & box.size;
      if (r.overlaps(screen) && r.intersect(screen).width > r.width * 0.9) {
        found.add(((e.widget as MushafPage).page, r));
      }
    }
    found.sort((a, b) => a.$2.left.compareTo(b.$2.left));
    return found;
  }

  testWidgets('iPad sideways: two facing pages, the odd one on the right', (
    tester,
  ) async {
    await open(tester, const Size(1366, 1024), 604);
    await shot(tester, 'ipad-landscape-604');
    final shown = pagesShown(tester);
    expect(shown.map((s) => s.$1), [604, 603]);
    final (_, left) = shown.first;
    final (_, right) = shown.last;
    // Same scale, and the two meet in the middle of the screen.
    expect(left.width, closeTo(right.width, 1));
    expect(left.height, closeTo(right.height, 1));
    expect((left.right + right.left) / 2, closeTo(1366 / 2, 24));
  });

  testWidgets('iPad upright: one page', (tester) async {
    await open(tester, const Size(1024, 1366), 604);
    await shot(tester, 'ipad-portrait-604');
    expect(pagesShown(tester).map((s) => s.$1), [604]);
  });

  testWidgets('a phone held sideways shows one page, not a spread', (
    tester,
  ) async {
    await open(tester, const Size(932, 430), 604);
    await shot(tester, 'phone-landscape-604');
    expect(pagesShown(tester).map((s) => s.$1), [604]);
  });

  testWidgets('elderly mode keeps the spread', (tester) async {
    await open(
      tester,
      const Size(1366, 1024),
      604,
      prefs: {'settings.elderlyMode': true},
    );
    await shot(tester, 'ipad-landscape-elderly');
    expect(pagesShown(tester).map((s) => s.$1), [604, 603]);
  });
}
