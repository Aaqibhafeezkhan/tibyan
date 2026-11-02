import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/continue_snapshot.dart';

SnapshotKey _key({
  String edition = 'madina1441',
  int page = 50,
  String look = 'a',
  bool landscape = false,
  int width = 400,
  int height = 800,
}) => SnapshotKey(
  edition: edition,
  page: page,
  look: look,
  landscape: landscape,
  width: width,
  height: height,
);

Future<ui.Image> _image() async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFF00FF00),
  );
  return r.endRecording().toImage(4, 4);
}

ReadingPositionRow _at(int page) => ReadingPositionRow(
  id: 1,
  edition: MushafEdition.madina1441.name,
  view: 'page',
  page: page,
  surah: 2,
  ayah: 1,
  updatedAt: DateTime(2026),
);

Future<List<Override>> _base(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final registry = (await tester.runAsync(
    () => ThemeRegistry.load(rootBundle),
  ))!;
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    themeRegistryProvider.overrideWithValue(registry),
    editionProvider.overrideWithValue(MushafEdition.madina1441),
  ];
}

void main() {
  group('SnapshotKey', () {
    test('matches only the same page, edition, look, orientation and size', () {
      expect(_key(), _key());
      expect(_key().hashCode, _key().hashCode);
      expect(_key(page: 51), isNot(_key()));
      expect(_key(edition: 'madina1405'), isNot(_key()));
      expect(_key(look: 'b'), isNot(_key()));
      expect(_key(landscape: true), isNot(_key()));
      expect(_key(width: 401), isNot(_key()));
      expect(_key(height: 801), isNot(_key()));
    });

    test('survives a round trip through JSON; junk reads as none', () {
      expect(SnapshotKey.fromJson(_key().toJson()), _key());
      expect(SnapshotKey.fromJson({'page': 'x'}), isNull);
      expect(SnapshotKey.fromJson(null), isNull);
    });

    test('the look changes with the theme and the colour mode', () {
      const s = AppSettings(styleId: 'classic');
      final base = snapshotLook(s, Brightness.light);
      expect(snapshotLook(s, Brightness.dark), isNot(base));
      expect(
        snapshotLook(s.copyWith(styleId: 'other'), Brightness.light),
        isNot(base),
      );
    });
  });

  group('ContinueSnapshots', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('snap'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'a picture is matched by its own key only, and kept on disk',
      () async {
        final store = ContinueSnapshots(() async => dir);
        await store.save(_key(), await _image());
        expect(store.match(_key()), isNotNull);
        expect(store.match(_key(page: 51)), isNull);
        expect(store.match(_key(look: 'dark')), isNull);

        final again = ContinueSnapshots(() async => dir);
        await again.load();
        expect(again.key, _key());
        expect(again.match(_key()), isNotNull);
      },
    );

    test('arming needs a match; a new picture replaces the old', () async {
      final store = ContinueSnapshots(() async => dir);
      store.arm(_key());
      expect(store.armed, isNull, reason: 'nothing saved yet');
      await store.save(_key(), await _image());
      store.arm(_key(width: 999));
      expect(store.armed, isNull, reason: 'another window size');
      store.arm(_key(), from: const Rect.fromLTWH(1, 2, 3, 4));
      expect(store.armed?.$1, _key());
      expect(store.origin, const Rect.fromLTWH(1, 2, 3, 4));
      await store.save(_key(page: 7), await _image());
      expect(store.armed, isNull, reason: 'the armed page is gone');
    });
  });

  testWidgets('the continue tap arms a matching picture synchronously', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('snap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ContinueSnapshots(() async => dir);
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await _base(tester),
          continueSnapshotsProvider.overrideWithValue(store),
          readingPositionProvider.overrideWith((ref) => Stream.value(_at(50))),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(readingPositionProvider);
              return Center(
                child: SizedBox(
                  width: 100,
                  height: 40,
                  child: Builder(
                    builder: (card) => GestureDetector(
                      onTap: () =>
                          openContinueReading(card, ref, () => opened = true),
                      child: const ColoredBox(
                        key: Key('card'),
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final card = tester.element(find.byKey(const Key('card')));
    final saved = SnapshotKey.of(
      card,
      ProviderScope.containerOf(card).read(settingsProvider),
      MushafEdition.madina1441,
      50,
    );
    final image = (await tester.runAsync(_image))!;
    await tester.runAsync(() => store.save(saved, image));
    await tester.tap(find.byKey(const Key('card')));
    // No pump: armed in the tap itself, before the mushaf builds.
    expect(opened, isTrue);
    expect(store.armed?.$1, saved);
    expect(store.origin!.size, const Size(100, 40));
  });

  group('ContinueTransition', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required bool reduce,
      required double t,
    }) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        value: t,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduce,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ContinueTransition(
              animation: controller,
              origin: const Rect.fromLTWH(20, 300, 360, 120),
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );
    }

    testWidgets('reduced motion only fades', (tester) async {
      await pumpAt(tester, reduce: true, t: 0.5);
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('otherwise the page grows from the card', (tester) async {
      await pumpAt(tester, reduce: false, t: 0);
      expect(find.byType(FadeTransition), findsNothing);
      expect(
        tester.getRect(find.byType(ClipRRect)),
        const Rect.fromLTWH(20, 300, 360, 120),
      );
      await pumpAt(tester, reduce: false, t: 1);
      expect(find.byType(FittedBox), findsNothing);
    });
  });

  testWidgets('prewarm starts after the first frame, then retargets', (
    tester,
  ) async {
    final warmed = <int>[];
    final positions = StreamController<ReadingPositionRow?>();
    addTearDown(positions.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await _base(tester),
          continueSnapshotsProvider.overrideWithValue(
            ContinueSnapshots(() async => Directory.systemTemp),
          ),
          readingPositionProvider.overrideWith((ref) => positions.stream),
        ],
        child: MaterialApp(
          home: ContinuePrewarm(
            warm: (ref, edition, page) async => warmed.add(page),
            child: const SizedBox(),
          ),
        ),
      ),
    );
    expect(warmed, isEmpty, reason: 'nothing before the first frame');
    positions.add(_at(50));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(warmed, [50, 51, 49], reason: 'the page first, then neighbours');

    warmed.clear();
    positions.add(_at(50));
    await tester.pumpAndSettle();
    expect(warmed, isEmpty, reason: 'same target: nothing again');

    positions.add(_at(200));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(warmed, [200, 201, 199]);
  });
}
