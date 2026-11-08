// Ad tour: drives the real app through its features for screen recording.
// Lines `CLIP:start:<name>` / `CLIP:end:<name>` tell the runner to start and
// stop the simulator recorder. Not committed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/mushaf_screen.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';
import 'package:tibyan/features/tasbih/tasbih_settings.dart';
import 'package:tibyan/features/tasbih/presentation/styles/misbaha_view.dart';
import 'package:tibyan/features/word_study/word_study_sheet.dart';
import 'package:tibyan/main.dart' as app;

import '../test/tools/render_hifz_progress_test.dart' show seed;

const only = String.fromEnvironment('ONLY');

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> ms(WidgetTester t, int n) => pumpFor(t, Duration(milliseconds: n));

/// Scrolls without a synthetic pointer (the live test binding draws one).
void scrollBy(WidgetTester t, double dy) {
  final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
  unawaited(pos.animateTo((pos.pixels + dy).clamp(0.0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 700), curve: Curves.easeInOut));
}

void turnPage(WidgetTester t) {
  final pc = t.widget<PageView>(find.byType(PageView).first).controller!;
  unawaited(pc.animateToPage(pc.page!.round() + 1,
      duration: const Duration(milliseconds: 1100), curve: Curves.easeInOut));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store trailer', (t) async {
    unawaited(app.main());
    while (find.byType(TibyanApp).evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await ms(t, 2500);
    final skip = find.byKey(const ValueKey('onboarding-skip-all'));
    if (skip.evaluate().isNotEmpty) {
      final w = t.widget(skip) as dynamic;
      (w.onPressed ?? w.onTap)();
      await ms(t, 2000);
    }
    final c = ProviderScope.containerOf(t.element(find.byType(TibyanApp)));
    final s = c.read(settingsProvider.notifier);
    final router = c.read(appRouterProvider);
    final db = c.read(userDatabaseProvider);

    // Seed: fawasil and a memorisation journey.
    for (final m in await db.watchBookmarkSets().first) {
      await db.deleteBookmarkSet(m.id);
    }
    for (final (name, color, surah, ayah, page) in [
      ('حفظ', 0xFF1D2F55, 2, 2, 2),
      ('تلاوة', 0xFFC69A3A, 2, 6, 3),
      ('مراجعة', 0xFF8E2F2F, 2, 17, 4),
    ]) {
      await db.addBookmarkSet(
          name: name, color: color, surah: surah, ayah: ayah, page: page);
    }
    try {
      await seed(db);
    } catch (e) {
      debugPrint('seed failed $e');
    }
    await s.setInterfaceStyle(InterfaceStyle.handasi);
    await s.setMode(ModeSetting.white);
    await s.setStyle('zakhrafa');
    await s.setPageTurn(PageTurn.fold);
    await s.setFasilStyle(FasilStyle.ribbon);
    await s.setReciter(2);

    Future<void> clip(String name, Future<void> Function() body) async {
      if (only.isNotEmpty && !only.split(',').contains(name)) return;
      debugPrint('CLIP:start:$name');
      await ms(t, 4800); // recorder start-up lag
      await body();
      debugPrint('CLIP:end:$name');
      await ms(t, 800);
    }

    void go(String loc) => router.go(loc);

    final side = c.read(sidebarCollapsedProvider.notifier);
    if (c.read(sidebarCollapsedProvider)) side.toggle();

    // 1. Home with the grouped sidebar; fold to icons and back.
    go('/');
    await ms(t, 3000);
    await clip('t1_home', () async {
      await ms(t, 2000);
      side.toggle();
      await ms(t, 2200);
      side.toggle();
      await ms(t, 2200);
    });

    // 2. Mushaf (sidebar hidden), two page turns.
    go(mushafLocation(2));
    await ms(t, 4000);
    await clip('t2_mushaf', () async {
      await ms(t, 1000);
      for (var i = 0; i < 2; i++) {
        turnPage(t);
        await ms(t, 2600);
      }
    });

    // 3. Tafsir under the verse.
    await s.setUnderVerse([7]);
    go('/read?s=2&a=2');
    await ms(t, 3000);
    await clip('t3_tafsir', () async {
      await ms(t, 1500);
      scrollBy(t, 300);
      await ms(t, 3000);
    });
    await s.setUnderVerse([]);

    // 4. Listening with word highlighting.
    go(mushafLocation(2));
    await ms(t, 3000);
    final rec = c.read(recitationProvider.notifier);
    await rec.play(2, from: 2, start: true);
    await ms(t, 4000);
    await clip('t4_listen', () async => ms(t, 7000));
    await rec.stop();
    await ms(t, 800);

    // 5. Khatma, then tasbih.
    go('/khatma');
    await ms(t, 2500);
    await clip('t5_khatma', () async => ms(t, 4000));
    final ts = c.read(tasbihSettingsProvider.notifier);
    await ts.setStyle(TasbihStyle.misbaha);
    await ts.setRender(MisbahaRender.real);
    await ts.setMaterial(BeadMaterial.amber);
    go('/tasbih');
    await ms(t, 2500);
    await clip('t6_tasbih', () async {
      for (var i = 0; i < 6; i++) {
        t.widget<MisbahaView>(find.byType(MisbahaView)).onCount();
        await ms(t, 650);
      }
      await ms(t, 600);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
