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

  testWidgets('ad tour', (t) async {
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
      await ms(t, 1500);
      await body();
      debugPrint('CLIP:end:$name');
      await ms(t, 800);
    }

    void go(String loc) => router.go(loc);

    if (const bool.fromEnvironment('DESKTOP')) {
      go('/');
      await ms(t, 3000);
      await clip('desk_home', () async => ms(t, 3000));
      go(mushafLocation(2));
      await ms(t, 4000);
      await clip('desk_spread', () async {
        await ms(t, 1500);
        turnPage(t);
        await ms(t, 2000);
      });
      return;
    }

    // 1. Home, geometric style.
    go('/');
    await ms(t, 2000);
    await clip('home', () async {
      await ms(t, 1200);
      scrollBy(t, 260);
      await ms(t, 1500);
      scrollBy(t, -260);
      await ms(t, 1500);
    });

    // 2. Mushaf page + curl turn (pages 2..4 carry the fawasil).
    go(mushafLocation(2));
    await ms(t, 3500);
    await clip('mushaf_curl', () async {
      await ms(t, 1000);
      final pc = t.widget<PageView>(find.byType(PageView).first).controller!;
      for (var i = 0; i < 2; i++) {
        unawaited(pc.animateToPage(pc.page!.round() + 1,
            duration: const Duration(milliseconds: 1100), curve: Curves.easeInOut));
        await ms(t, 2200);
      }
    });

    // 3. Fawasil list.
    go('/mushaf/fawasil');
    await ms(t, 2000);
    await clip('fawasil', () async => ms(t, 3000));

    // 4. Listening with word highlighting.
    go(mushafLocation(2));
    await ms(t, 3000);
    final rec = c.read(recitationProvider.notifier);
    await rec.play(2, from: 2, start: true);
    await ms(t, 4000);
    await clip('listen', () async => ms(t, 5000));
    await rec.stop();
    await ms(t, 800);

    // 5. Tafsir under the verse.
    await s.setUnderVerse([7]);
    go('/read?s=2&a=2');
    await ms(t, 3000);
    await clip('tafsir', () async {
      await ms(t, 1500);
      final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      unawaited(pos.animateTo(pos.pixels + 260,
          duration: const Duration(milliseconds: 900), curve: Curves.easeInOut));
      await ms(t, 2000);
    });
    await s.setUnderVerse([]);

    // 6. Word study.
    go(mushafLocation(3));
    await ms(t, 3000);
    await clip('word', () async {
      await ms(t, 600);
      unawaited(showWordStudy(t.element(find.byType(MushafScreen)),
          surah: 2, ayah: 6, word: 3));
      await ms(t, 3500);
    });
    if (router.canPop()) router.pop();
    await ms(t, 800);

    // 7. Hifz journey.
    go('/hifz');
    await ms(t, 2500);
    await clip('hifz', () async {
      await ms(t, 1500);
      scrollBy(t, 300);
      await ms(t, 2000);
    });
    go('/hifz/map');
    await ms(t, 2500);
    await clip('hifz_map', () async => ms(t, 3500));

    // 8. Tasbih 3D misbaha.
    final ts = c.read(tasbihSettingsProvider.notifier);
    await ts.setStyle(TasbihStyle.misbaha);
    await ts.setRender(MisbahaRender.real);
    await ts.setMaterial(BeadMaterial.amber);
    go('/tasbih');
    await ms(t, 2500);
    await clip('tasbih', () async {
      for (var i = 0; i < 5; i++) {
        t.widget<MisbahaView>(find.byType(MisbahaView)).onCount();
        await ms(t, 650);
      }
      await ms(t, 600);
    });

    // 9. Interface styles + night.
    go('/');
    await ms(t, 2000);
    await clip('styles', () async {
      await ms(t, 900);
      await s.setInterfaceStyle(InterfaceStyle.makhtuta);
      await ms(t, 1600);
      await s.setInterfaceStyle(InterfaceStyle.layli);
      await ms(t, 1600);
      await s.setInterfaceStyle(InterfaceStyle.handasi);
      await s.setMode(ModeSetting.night);
      await ms(t, 1800);
    });
    go(mushafLocation(3));
    await ms(t, 3000);
    await clip('night_mushaf', () async => ms(t, 2500));
    await s.setMode(ModeSetting.white);

    // 10. Elderly mode.
    await s.setElderlyMode(true);
    go('/');
    await ms(t, 2500);
    await clip('elderly', () async {
      await ms(t, 1500);
      scrollBy(t, 200);
      await ms(t, 1500);
    });
    go(mushafLocation(3));
    await ms(t, 3000);
    await clip('elderly_mushaf', () async => ms(t, 2500));
    await s.setElderlyMode(false);

    // 11. Downloads (offline).
    go('/downloads');
    await ms(t, 2000);
    await clip('offline', () async => ms(t, 3000));
    SchedulerBinding.instance.ensureVisualUpdate();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
