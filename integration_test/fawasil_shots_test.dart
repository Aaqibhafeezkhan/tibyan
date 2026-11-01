// Screenshots of fawasil management: the index's «الفواصل» tab, the move
// dialog, the sheet at the limit of eight, and a page with mixed looks,
// in light and night.
//
//   flutter test integration_test/fawasil_shots_test.dart -d <device>
//
// Uses the device's own app data (run it on a simulator made for it).
// Each picture is printed as base64 lines «PNG:<name>:<chunk>» and
// «PNGEND:<name>», joined into files by a shell.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/fawasil_manage.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';
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
  final px = view.flutterView.physicalSize;
  final image = await layer.toImage(Offset.zero & px, pixelRatio: 1);
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

  testWidgets('fawasil management screenshots', (t) async {
    unawaited(app.main());
    while (find.byType(TibyanApp).evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await pumpFor(t, const Duration(seconds: 3));
    final skip = find.byKey(const ValueKey('onboarding-skip-all'));
    if (skip.evaluate().isNotEmpty) {
      await t.tap(skip);
      await pumpFor(t, const Duration(seconds: 2));
    }
    final c = ProviderScope.containerOf(t.element(find.byType(TibyanApp)));
    final s = c.read(settingsProvider.notifier);
    final db = c.read(userDatabaseProvider);
    final router = c.read(appRouterProvider);
    for (final m in await db.watchBookmarkSets().first) {
      await db.deleteBookmarkSet(m.id);
    }
    await s.setFasilStyle(FasilStyle.ribbon);
    await s.setFasilMaterial(FasilMaterial.silk);
    // Page 50 (Al Imran 3:1-…): a ribbon, a velvet ribbon and a tab.
    final ids = <int>[];
    for (final (name, color, surah, ayah, page) in [
      ('حفظ', 0xFF2F5E9E, 3, 1, 50),
      ('تلاوة', 0xFFB23A3A, 3, 5, 50),
      ('مراجعة', 0xFF2E7D5B, 3, 9, 50),
      ('الكهف', 0xFFB7860B, 18, 1, 293),
      ('يس', 0xFF7A4A9E, 36, 1, 440),
      ('الملك', 0xFF3A7F8C, 67, 1, 562),
      ('البقرة', 0xFFB23A3A, 2, 255, 42),
      ('الرحمن', 0xFF2F5E9E, 55, 1, 531),
    ]) {
      ids.add(
        await db.addBookmarkSet(
          name: name,
          color: color,
          surah: surah,
          ayah: ayah,
          page: page,
        ),
      );
    }
    await db.setBookmarkSetStyle(ids[1], look: 'ribbon', material: 'velvet');
    await db.setBookmarkSetStyle(ids[2], look: 'tab', material: null);
    await db.setBookmarkSetStyle(ids[4], look: 'tint', material: null);
    await db.savePosition(
      edition: 'madina1441',
      view: 'page',
      surah: 3,
      ayah: 1,
      page: 50,
    );

    for (final (mode, tag) in [
      (ModeSetting.light, 'light'),
      (ModeSetting.night, 'night'),
    ]) {
      await s.setMode(mode);
      router.go(mushafLocation(50));
      await pumpFor(t, const Duration(seconds: 4));
      await snap(t, 'page-mixed-$tag');

      router.go('/mushaf/index?tab=fawasil');
      await pumpFor(t, const Duration(seconds: 3));
      await snap(t, 'index-fawasil-$tag');

      await t.tap(find.byKey(ValueKey('fawasil-menu-${ids[3]}')));
      await pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.text('انقل إلى…'));
      await pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.byKey(const ValueKey('fasil-move-verse')));
      await snap(t, 'move-dialog-$tag');
      await t.tap(find.text('إلغاء').last);
      await pumpFor(t, const Duration(seconds: 1));

      await t.tap(find.byKey(ValueKey('fawasil-menu-${ids[2]}')));
      await pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.text('غيّر الشكل والخامة واللون'));
      await snap(t, 'style-editor-$tag');
      Navigator.of(
        t.element(find.byKey(const ValueKey('fasil-follow-default'))),
      ).pop();
      await pumpFor(t, const Duration(seconds: 1));

      final ctx = t.element(find.byType(FawasilIndexTab));
      unawaited(showFawasilLimit(ctx, here: (surah: 1, ayah: 1), page: 1));
      await snap(t, 'limit-sheet-$tag');
      Navigator.of(t.element(find.byKey(ValueKey('fasil-limit-${ids[0]}'))))
          .pop();
      await pumpFor(t, const Duration(seconds: 1));
    }
    expect(maxFawasil, 8);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
