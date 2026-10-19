// Frame times of page turns with four named fawasil (two on the page
// read, two folded at its edge), in each look and page-turn effect.
//
// Run in profile mode on a device or emulator:
//   flutter drive --profile -d <device> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/fawasil_perf_test.dart
//
// Prints one line per case: PERF <look>/<effect> frames=… build avg/p90/
// max, raster avg/p90/max (ms), janky (>16.7 ms) frames.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';
import 'package:tibyan/main.dart' as app;

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

String stats(List<double> v) {
  if (v.isEmpty) return '-';
  final s = [...v]..sort();
  final avg = v.reduce((a, b) => a + b) / v.length;
  final p90 = s[(s.length * .9).floor().clamp(0, s.length - 1)];
  return '${avg.toStringAsFixed(1)}/${p90.toStringAsFixed(1)}/'
      '${s.last.toStringAsFixed(1)}';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('fawasil page-turn frame times', (t) async {
    unawaited(app.main());
    while (find.byType(TibyanApp).evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await pumpFor(t, const Duration(seconds: 2));
    final skip = find.byKey(const ValueKey('onboarding-skip-all'));
    if (skip.evaluate().isNotEmpty) {
      await t.tap(skip);
      await pumpFor(t, const Duration(seconds: 2));
    }
    final c = ProviderScope.containerOf(t.element(find.byType(TibyanApp)));
    final s = c.read(settingsProvider.notifier);
    final db = c.read(userDatabaseProvider);
    for (final m in await db.watchBookmarkSets().first) {
      await db.deleteBookmarkSet(m.id);
    }
    for (final (name, color, surah, ayah, page) in [
      ('حفظ', 0xFF1D2F55, 3, 1, 50),
      ('تلاوة', 0xFFC69A3A, 3, 5, 50),
      ('مراجعة', 0xFFEFE3C6, 3, 16, 52),
      ('ورد', 0xFF2E5E4A, 4, 135, 100),
    ]) {
      await db.addBookmarkSet(
        name: name,
        color: color,
        surah: surah,
        ayah: ayah,
        page: page,
      );
    }

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> f) => timings.addAll(f);

    for (final style in [FasilStyle.tint, FasilStyle.ribbon, FasilStyle.tab]) {
      await s.setFasilStyle(style);
      for (final effect in [PageTurn.normal, PageTurn.curl, PageTurn.fold]) {
        await s.setPageTurn(effect);
        c.read(appRouterProvider).go(mushafLocation(50));
        await pumpFor(t, const Duration(seconds: 3));
        timings.clear();
        SchedulerBinding.instance.addTimingsCallback(collect);
        // Four turns forward and back over the fawasil's pages.
        for (var i = 0; i < 4; i++) {
          final pager = find.byType(PageView).first;
          await t.fling(pager, Offset(i.isEven ? 320 : -320, 0), 1400);
          await pumpFor(t, const Duration(milliseconds: 1200));
        }
        await pumpFor(t, const Duration(milliseconds: 500));
        SchedulerBinding.instance.removeTimingsCallback(collect);
        final build = [
          for (final f in timings) f.buildDuration.inMicroseconds / 1000,
        ];
        final raster = [
          for (final f in timings) f.rasterDuration.inMicroseconds / 1000,
        ];
        final janky = timings
            .where(
              (f) =>
                  f.buildDuration.inMicroseconds > 16700 ||
                  f.rasterDuration.inMicroseconds > 16700,
            )
            .length;
        debugPrint(
          'PERF ${style.name}/${effect.name} frames=${timings.length} '
          'build=${stats(build)} raster=${stats(raster)} janky=$janky',
        );
      }
    }
    expect(c.read(editionProvider), isNotNull);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
