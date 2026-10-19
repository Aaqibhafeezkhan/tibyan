import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_sheet.dart';

import '../testing/bundled_pages.dart';

/// Not a test: draws the reading screen with named fawasil in each look
/// (tinted verse, ribbon, tab) and mode, their positions, focus mode,
/// several fawasil, a tablet spread, the settings card and the first-time
/// chooser into `$FAWASIL_OUT/<name>.png`, and the frames of a fasil being
/// placed and of a page turn into `$FAWASIL_OUT/frames_*`. Runs only with
/// RENDER_FAWASIL=1.
void main() {
  final run = Platform.environment['RENDER_FAWASIL'] == '1';
  final outPath = Platform.environment['FAWASIL_OUT'] ?? 'build/fawasil';
  const phone = Size(393, 852);
  const tablet = Size(1366, 1024);

  testWidgets(
    'render fawasil previews',
    (tester) async {
      for (final m in ['toggle', 'isEnabled']) {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.$m',
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
            m == 'isEnabled' ? false : null,
          ]),
        );
      }
      final db = ContentDatabase(
        NativeDatabase(
          File('assets/db/content.db'),
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
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
      });
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      final flags = (await tester.runAsync(
        () => FeatureFlags.load(rootBundle),
      ))!;
      final out = Directory(outPath)..createSync(recursive: true);
      final root = Directory.systemTemp.createTempSync('fawasil');
      final dir = Directory(p.join(root.path, 'packs', 'pages-hafs-1441-v1'))
        ..createSync(recursive: true);
      final zip = bundledPagesArchive();
      for (final pg in [1, 2, 3, 49, 50, 51, 52, 53]) {
        final e = zip.findFile('${pg.toString().padLeft(3, '0')}.svg.xz')!;
        File(p.join(dir.path, e.name)).writeAsBytesSync(e.content);
      }
      File(p.join(dir.path, '.installed')).writeAsStringSync('x');

      final boundary = GlobalKey();
      Future<Uint8List> grab() async {
        final object =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await object.toImage(pixelRatio: 2);
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        }))!;
      }

      Future<void> settle() async {
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      /// Opens [location] with [prefs] and the fawasil [seed] (name,
      /// colour, verse), then [then] (which may take its own shots).
      Future<void> scene(
        String? name,
        String location,
        Size size, {
        Map<String, Object> prefs = const {},
        List<(String, int, int, int)> seed = const [],
        Future<void> Function(ProviderContainer, UserDatabase)? then,
      }) async {
        SharedPreferences.setMockInitialValues({
          'settings.onboardingDone': true,
          'settings.language': 'ar',
          'settings.mode': 'light',
          whatsNewSeenKey: whatsNewId,
          ...prefs,
        });
        final shared = await SharedPreferences.getInstance();
        final user = UserDatabase(NativeDatabase.memory());
        await tester.runAsync(() async {
          for (final (n, c, s, a) in seed) {
            await user.addBookmarkSet(
              name: n,
              color: c,
              surah: s,
              ayah: a,
              page: 0,
            );
          }
        });
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = 2;
        final container = ProviderContainer(
          overrides: [
            themeRegistryProvider.overrideWithValue(registry),
            featureFlagsProvider.overrideWithValue(flags),
            sharedPreferencesProvider.overrideWithValue(shared),
            contentDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(user),
            packRootProvider.overrideWithValue(root),
            readingPositionProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              key: UniqueKey(),
              container: container,
              child: const TibyanApp(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        container.read(appRouterProvider).go(location);
        await settle();
        if (name != null) {
          File('${out.path}/$name.png').writeAsBytesSync(await grab());
        }
        await then?.call(container, user);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }

      const navy = 0xFF1D2F55, mustard = 0xFFC69A3A, cream = 0xFFEFE3C6;
      const red = 0xFFB23A3A, green = 0xFF2E7D5B, blue = 0xFF2F5E9E;
      const gold = 0xFFB7860B;

      // 1. Each look in light and night, one fasil on page 50 and three
      //    folded elsewhere.
      for (final style in ['tint', 'ribbon', 'tab']) {
        for (final mode in ['light', 'night']) {
          final card = style == 'tab';
          await scene(
            'style_${style}_$mode',
            '/mushaf?page=50',
            phone,
            prefs: {'settings.fasilStyle': style, 'settings.mode': mode},
            seed: [
              ('مراجعة', card ? navy : blue, 3, 1),
              ('حفظ', card ? mustard : red, 3, 10),
              ('تلاوة', card ? cream : green, 3, 16),
              ('ورد', card ? 0xFF8C2F2F : gold, 4, 135),
            ],
          );
        }
      }
      // 2. Materials, tassel and positions.
      for (final mat in ['silk', 'linen', 'velvet']) {
        await scene(
          'ribbon_$mat',
          '/mushaf?page=50',
          phone,
          prefs: {
            'settings.fasilStyle': 'ribbon',
            'settings.fasilMaterial': mat,
          },
          seed: [('حفظ', mat == 'velvet' ? 0xFF5B1F3A : red, 3, 1)],
        );
      }
      for (final style in ['ribbon', 'tab']) {
        await scene(
          'side_$style',
          '/mushaf?page=51',
          phone,
          prefs: {'settings.fasilStyle': style, 'settings.fasilPlace': 'side'},
          seed: [('تلاوة', style == 'tab' ? mustard : green, 3, 10)],
        );
      }
      // 3. Focus mode.
      for (final style in ['ribbon', 'tab']) {
        await scene(
          'focus_$style',
          '/mushaf?page=50',
          phone,
          prefs: {'settings.fasilStyle': style, 'settings.focusMode': true},
          seed: [
            ('حفظ', style == 'tab' ? navy : red, 3, 1),
            ('تلاوة', style == 'tab' ? mustard : green, 3, 16),
          ],
        );
      }
      // 4. Several on one page.
      for (final style in ['ribbon', 'tab']) {
        await scene(
          'multi_$style',
          '/mushaf?page=50',
          phone,
          prefs: {'settings.fasilStyle': style},
          seed: [
            ('حفظ', style == 'tab' ? navy : red, 3, 1),
            ('مراجعة', style == 'tab' ? cream : blue, 3, 5),
            ('تلاوة', style == 'tab' ? mustard : green, 3, 16),
            ('ورد', style == 'tab' ? 0xFF2E5E4A : gold, 4, 135),
          ],
        );
      }
      // 5. Interface styles × white / night.
      for (final iface in ['makhtuta', 'handasi', 'layli']) {
        for (final mode in ['white', 'night']) {
          await scene(
            'iface_${iface}_$mode',
            '/mushaf?page=50',
            phone,
            prefs: {
              'settings.fasilStyle': iface == 'handasi' ? 'tab' : 'ribbon',
              'settings.interfaceStyle': iface,
              'settings.mode': mode,
            },
            seed: [
              ('حفظ', iface == 'handasi' ? mustard : red, 3, 1),
              ('تلاوة', iface == 'handasi' ? navy : green, 3, 16),
            ],
          );
        }
      }
      // 6. A tablet spread (pages 50 and 51).
      for (final style in ['ribbon', 'tab']) {
        await scene(
          'tablet_$style',
          '/mushaf?page=50',
          tablet,
          prefs: {'settings.fasilStyle': style},
          seed: [
            ('حفظ', style == 'tab' ? navy : red, 3, 1),
            ('مراجعة', style == 'tab' ? cream : gold, 3, 10),
            ('تلاوة', style == 'tab' ? mustard : green, 4, 135),
          ],
        );
      }
      // 7. The settings card, in each look.
      for (final style in ['tint', 'ribbon', 'tab']) {
        await scene(
          'settings_$style',
          '/settings/section/mushaf?focus=fasilStyle',
          phone,
          prefs: {'settings.fasilStyle': style},
        );
      }
      // 8. The first-time chooser.
      for (final mode in ['light', 'night']) {
        await scene(
          null,
          '/mushaf?page=50',
          phone,
          prefs: {'settings.mode': mode},
          then: (container, _) async {
            final nav = tester.element(find.byType(Scaffold).first);
            unawaited(
              showModalBottomSheet<void>(
                context: nav,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => const LookTheme(child: FasilStyleChooser()),
              ),
            );
            await settle();
            File('${out.path}/chooser_$mode.png')
                .writeAsBytesSync(await grab());
          },
        );
      }
      // 9. Motion: a ribbon placed, a tab placed, then a page turn.
      for (final style in ['ribbon', 'tab']) {
        await scene(
          null,
          '/mushaf?page=50',
          phone,
          prefs: {'settings.fasilStyle': style, 'settings.pageTurn': 'normal'},
          then: (container, user) async {
            final frames = Directory('${out.path}/frames_add_$style')
              ..createSync(recursive: true);
            var n = 0;
            Future<void> frame() async =>
                File('${frames.path}/${(n++).toString().padLeft(3, '0')}.png')
                    .writeAsBytesSync(await grab());
            for (var i = 0; i < 4; i++) {
              await frame();
            }
            armFasilEntrance();
            await tester.runAsync(
              () => user.addBookmarkSet(
                name: style == 'tab' ? 'حفظ' : 'تلاوة',
                color: style == 'tab' ? navy : green,
                surah: 3,
                ayah: 1,
                page: 50,
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)),
            );
            for (var i = 0; i < 26; i++) {
              await tester.pump(const Duration(milliseconds: 33));
              await frame();
            }
            // The page turns: the ribbon goes with page 50.
            final gesture = await tester.startGesture(const Offset(80, 420));
            for (var i = 0; i < 18; i++) {
              await gesture.moveBy(const Offset(14, 0));
              await tester.pump(const Duration(milliseconds: 33));
              await frame();
            }
            await gesture.up();
            for (var i = 0; i < 16; i++) {
              await tester.pump(const Duration(milliseconds: 33));
              await frame();
            }
          },
        );
      }
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(db.close);
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
