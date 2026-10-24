import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/mushaf/data/mushaf_repository.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/share_image/share_art.dart';
import 'package:tibyan/features/share_image/share_document.dart';
import 'package:tibyan/features/share_image/share_source.dart';

import '../testing/bundled_pages.dart';

/// Not a test: draws a passage of al-Baqarah shared as pictures, before
/// (the text set again) and after (the mushaf's own pages, cut at line
/// boundaries), into `$SHARE_ART_OUT` (default build/share_art). Madina
/// 1441 only: its pages ship with the app. Runs only with
/// RENDER_SHARE_ART=1.
void main() {
  final run = Platform.environment['RENDER_SHARE_ART'] == '1';
  final outPath = Platform.environment['SHARE_ART_OUT'] ?? 'build/share_art';

  testWidgets(
    'render share art',
    (tester) async {
      final db = ContentDatabase(
        NativeDatabase(
          File('assets/db/content.db'),
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
        ),
      );
      final repo = MushafRepository(db);
      final out = Directory(outPath)..createSync(recursive: true);
      final root = Directory.systemTemp.createTempSync('share_art');
      final pages = Directory(p.join(root.path, 'packs', 'pages-hafs-1441-v1'))
        ..createSync(recursive: true);
      for (final e in bundledPagesArchive().files) {
        File(p.join(pages.path, e.name)).writeAsBytesSync(e.content);
      }
      File(p.join(pages.path, '.installed')).writeAsStringSync('x');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => root.path,
      );
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentDatabaseProvider.overrideWithValue(db),
            themeRegistryProvider.overrideWithValue(registry),
            sharedPreferencesProvider.overrideWithValue(sp),
            packRootProvider.overrideWithValue(root),
            editionProvider.overrideWithValue(MushafEdition.madina1441),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

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
        final surahs = await repo.surahs();
        final codec = await ui.instantiateImageCodec(
          File('assets/ornaments/share_logo.png').readAsBytesSync(),
        );
        final logo = (await codec.getNextFrame()).image;

        Future<void> draw(String name, ShareRange range) async {
          final passage = await hafsPassage(
            repo: repo,
            range: range,
            surahs: surahs,
          );
          final before = ShareDocument.build(passage, logo: logo);
          for (var i = 0; i < before.pageCount; i++) {
            File('${out.path}/${name}_before_${i + 1}.png')
                .writeAsBytesSync(await before.png(i));
          }
          before.dispose();
          final art = await shareArtPages(widgetRef, range);
          final after = ShareDocument.art(passage, art!, logo: logo);
          for (var i = 0; i < after.pageCount; i++) {
            File('${out.path}/${name}_after_${i + 1}.png')
                .writeAsBytesSync(await after.png(i));
          }
          after.dispose();
        }

        // From the middle of page 3 to the middle of page 4.
        await draw('baqarah_10_22', [
          for (var a = 10; a <= 22; a++) (surah: 2, ayah: a),
        ]);
        // A whole short surah opening mid-page, then the next one.
        await draw('mulk', [
          for (var a = 1; a <= 30; a++) (surah: 67, ayah: a),
        ]);
        logo.dispose();
      });
      await tester.runAsync(db.close);
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
