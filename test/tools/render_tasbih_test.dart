import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:tibyan/features/tasbih/data/tasbih_repository.dart';
import 'package:tibyan/features/tasbih/domain/dhikr.dart';
import 'package:tibyan/features/tasbih/platform/tasbih_platform.dart';
import 'package:tibyan/features/tasbih/tasbih_providers.dart';

/// Not a test: draws «المسبحة» for review: each style in light and night,
/// the true-3D beads in each material, the target reached, the laptop
/// layout, elderly mode, the settings card, the daily log, the home tile
/// and the widget's layout, into `$TASBIH_OUT/<name>.png`. Runs only with
/// RENDER_TASBIH=1.
void main() {
  final run = Platform.environment['RENDER_TASBIH'] == '1';
  final outPath = Platform.environment['TASBIH_OUT'] ?? 'build/tasbih_previews';
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final adhkar = parseAppAdhkar(
    File('assets/tasbih/adhkar.json').readAsStringSync(),
  );

  testWidgets(
    'render tasbih previews',
    (tester) async {
      for (final m in ['toggle', 'isEnabled']) {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.$m',
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
            m == 'isEnabled' ? false : null,
          ]),
        );
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      debugDisableShadows = false;
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

      Future<void> shot(
        String name,
        String location, {
        Size logical = const Size(393, 852),
        double top = 59,
        double bottom = 34,
        Map<String, Object> prefs = const {},
        int taps = 0,
        bool log = false,
        Widget? child,
      }) async {
        SharedPreferences.setMockInitialValues({
          'settings.onboardingDone': true,
          'settings.language': 'ar',
          'settings.style': 'zakhrafa',
          'settings.mode': 'light',
          'settings.interfaceStyle': 'handasi',
          'settings.tasbih.target': 33,
          whatsNewSeenKey: whatsNewId,
          ...prefs,
        });
        final shared = await SharedPreferences.getInstance();
        final user = UserDatabase(NativeDatabase.memory());
        tester.view.physicalSize = logical * 2;
        tester.view.devicePixelRatio = 2;
        tester.view.padding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
        tester.view.viewPadding = FakeViewPadding(
          top: top * 2,
          bottom: bottom * 2,
        );
        final container = ProviderContainer(
          overrides: [
            themeRegistryProvider.overrideWithValue(registry),
            featureFlagsProvider.overrideWithValue(flags),
            sharedPreferencesProvider.overrideWithValue(shared),
            contentDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(user),
            readingPositionProvider.overrideWith((ref) => Stream.value(null)),
            appAdhkarProvider.overrideWith((ref) => adhkar),
            tasbihPlatformProvider.overrideWithValue(NoTasbihPlatform()),
          ],
        );
        if (log) {
          final repo = TasbihRepository(user);
          final now = DateTime.now();
          await tester.runAsync(() async {
            await repo.record('app:seen34', count: 133, rounds: 1, at: now);
            await repo.record('app:seen33', count: 41, at: now);
            await repo.record(
              'app:seen34',
              count: 100,
              rounds: 1,
              at: now.subtract(const Duration(days: 1)),
            );
            await repo.record(
              'app:seen33',
              count: 27,
              at: now.subtract(const Duration(days: 3)),
            );
          });
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              key: UniqueKey(),
              container: container,
              child: child ?? const TibyanApp(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        if (child == null) container.read(appRouterProvider).go(location);
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        for (var i = 0; i < taps; i++) {
          await tester.runAsync(
            () => container.read(tasbihCounterProvider.notifier).tap(),
          );
        }
        await settle();
        final object =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await object.toImage(pixelRatio: 2);
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        });
        File('${out.path}/$name.png').writeAsBytesSync(bytes!);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        container.dispose();
        tester.takeException();
      }

      for (final mode in ['light', 'night']) {
        for (final style in ['misbaha', 'button', 'lcd', 'screen']) {
          await shot(
            '${style}_$mode',
            '/tasbih',
            prefs: {'settings.mode': mode, 'settings.tasbih.style': style},
            taps: 13,
          );
        }
        for (final material in ['amber', 'wood', 'pearl']) {
          await shot(
            'real3d_${material}_$mode',
            '/tasbih',
            prefs: {
              'settings.mode': mode,
              'settings.tasbih.render': 'real',
              'settings.tasbih.material': material,
            },
            taps: 13,
          );
        }
        await shot(
          'settings_$mode',
          '/settings/section/tasbih',
          prefs: {'settings.mode': mode},
        );
        await shot(
          'log_$mode',
          '/tasbih/log',
          prefs: {'settings.mode': mode},
          log: true,
        );
        await shot(
          'home_$mode',
          '/',
          prefs: {'settings.mode': mode},
          log: true,
        );
      }
      for (final look in ['makhtuta', 'layli']) {
        await shot(
          'misbaha_$look',
          '/tasbih',
          prefs: {'settings.interfaceStyle': look},
          taps: 5,
        );
      }
      await shot(
        'round_closed_light',
        '/tasbih',
        prefs: {'settings.tasbih.style': 'button'},
        taps: 33,
      );
      await shot(
        'elderly_button_light',
        '/tasbih',
        prefs: {
          'settings.elderlyMode': true,
          'settings.tasbih.style': 'button',
        },
        taps: 7,
      );
      await shot(
        'english_misbaha_light',
        '/tasbih',
        prefs: {'settings.language': 'en'},
        taps: 3,
      );
      await shot(
        'laptop_misbaha_light',
        '/tasbih',
        logical: const Size(1440, 900),
        top: 0,
        bottom: 0,
        prefs: {'settings.tasbih.render': 'real'},
        taps: 21,
      );
      await shot(
        'widget_layout',
        '',
        logical: const Size(393, 200),
        top: 0,
        bottom: 0,
        child: const _WidgetLayout(),
      );
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

/// The home screen widget's layout as `res/layout/tasbih_widget.xml` draws
/// it (same colours and sizes), for review away from a device.
class _WidgetLayout extends StatelessWidget {
  const _WidgetLayout();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFF8E9AA6),
        child: Center(
          child: Container(
            width: 300,
            height: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12402F),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parseAppAdhkar(
                          File('assets/tasbih/adhkar.json').readAsStringSync(),
                        ).adhkar.first.text,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Color(0xFFB8923E),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        '١٣٣',
                        style: TextStyle(
                          color: Color(0xFFF2EBDD),
                          fontSize: 30,
                          fontFamily: 'TibyanDigits',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A45C),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'عُدّ',
                    style: TextStyle(
                      color: Color(0xFF1B2A2A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
