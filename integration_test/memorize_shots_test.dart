// Screenshots of memorization mode (hidden words): each hiding style, a
// reveal, light and night, and the 1405 and Shamarly editions.
//
//   flutter test integration_test/memorize_shots_test.dart -d <device>
//
// Settings live in memory (mock preferences), so the device's own
// settings are untouched. Each picture is printed as base64 lines
// «PNG:<name>:<chunk>» and «PNGEND:<name>»; tools/apple or a shell joins
// them into files.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/features/hifz/data/memorize_prefs.dart';
import 'package:tibyan/features/hifz/domain/memorize_session.dart';
import 'package:tibyan/features/mushaf/data/page_pack.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/l10n/app_localizations.dart';
import 'package:tibyan/main.dart' as app;

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> snap(WidgetTester t, String name) async {
  await pumpFor(t, const Duration(seconds: 2));
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final b64 = base64Encode(bytes!.buffer.asUint8List());
  for (var i = 0; i < b64.length; i += 2000) {
    // ignore: avoid_print
    print('PNG:$name:${b64.substring(i, (i + 2000).clamp(0, b64.length))}');
    if (i % 200000 == 0) await Future<void>.delayed(Duration.zero);
  }
  // ignore: avoid_print
  print('PNGEND:$name');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('memorization mode screenshots', (t) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'settings.mode': 'light',
      'settings.defaultsRev': 1,
    });
    unawaited(app.main());
    while (find.byType(TibyanApp).evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await pumpFor(t, const Duration(seconds: 3));
    final c = ProviderScope.containerOf(t.element(find.byType(TibyanApp)));
    final s = c.read(settingsProvider.notifier);
    final prefs = c.read(memorizePrefsProvider.notifier);
    var n = 0;

    Future<void> open(int page, MaskStyle style, {String from = ''}) async {
      await prefs.setStyle(style);
      c
          .read(appRouterProvider)
          .go('/mushaf?page=$page&memorize=1$from&n=${n++}');
      await pumpFor(t, const Duration(seconds: 4));
    }

    AppLocalizations l() =>
        AppLocalizations.of(t.element(find.byType(Scaffold).last));

    for (final mode in [ModeSetting.light, ModeSetting.night]) {
      await s.setMode(mode);
      for (final style in MaskStyle.values) {
        await open(50, style);
        if (style == MaskStyle.progressive) {
          // Two repetitions: every other word.
          for (var i = 0; i < 2; i++) {
            await t.tap(find.byIcon(Icons.replay).last);
            await pumpFor(t, const Duration(milliseconds: 500));
          }
        }
        await snap(t, '1441_${mode.name}_${style.name}');
      }
      // Reveal: a word under a tap, then the verse.
      await open(50, MaskStyle.all);
      final page = t.getRect(find.byType(MushafPage).first);
      await t.tapAt(page.center);
      await pumpFor(t, const Duration(milliseconds: 600));
      await t.tap(find.text(l().memorizeRevealVerse));
      await snap(t, '1441_${mode.name}_reveal');
    }
    await s.setMode(ModeSetting.light);

    // A stretch of verses (from the verse services / hifz screen).
    await open(50, MaskStyle.all, from: '&from=3:1&to=3:5');
    await snap(t, '1441_light_range');

    for (final ed in [MushafEdition.madina1405, MushafEdition.shamarly]) {
      final keep = c.listen(editionDownloadProvider(ed), (_, _) {});
      if (c.read(editionDownloadProvider(ed)).phase != PackPhase.installed) {
        unawaited(c.read(editionDownloadProvider(ed).notifier).start());
        final end = DateTime.now().add(const Duration(minutes: 20));
        while (c.read(editionDownloadProvider(ed)).phase !=
                PackPhase.installed &&
            DateTime.now().isBefore(end)) {
          await t.pump(const Duration(milliseconds: 500));
        }
      }
      keep.close();
      if (c.read(editionDownloadProvider(ed)).phase != PackPhase.installed) {
        debugPrint('MEMO: ${ed.name} not installed');
        continue;
      }
      await s.setEdition(ed);
      await pumpFor(t, const Duration(seconds: 1));
      for (final style in [MaskStyle.alternate, MaskStyle.firstLetter]) {
        await open(50, style);
        await snap(t, '${ed.name}_light_${style.name}');
      }
    }
    await s.setEdition(MushafEdition.madina1441);
  });
}
