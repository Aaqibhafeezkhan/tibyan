import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/hifz/hifz_providers.dart';
import 'package:tibyan/features/home/home_screen.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/illuminated_frame.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/page_interaction.dart';
import 'package:tibyan/features/onboarding/background_downloads.dart';
import 'package:tibyan/features/onboarding/onboarding_tasmee_screen.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_settings_screen.dart'
    show tasmeeModelInfoProvider;
import 'package:tibyan/l10n/app_localizations.dart';

import '../testing/bundled_pages.dart';

/// Not a test: renders the «فاتح» and «أبيض زاهي» home screens and mushaf
/// pages side by side in each interface style, and the first-run tasmee
/// step, into `build/ui_fixes/`. Runs only with RENDER_UI_FIXES=1.
void main() {
  final run = Platform.environment['RENDER_UI_FIXES'] == '1';
  const phone = Size(393, 852);

  testWidgets('render the ui fixes', (tester) async {
    await tester.runAsync(() async {
      final manifest = jsonDecode(
        await rootBundle.loadString('FontManifest.json'),
      ) as List<dynamic>;
      for (final f in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(f['family'] as String);
        for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(Uri.decodeFull(a['asset'] as String)));
        }
        await loader.load();
      }
    });
    final db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    final root = Directory.systemTemp.createTempSync('render');
    final pages = Directory(p.join(root.path, 'packs', 'pages-hafs-1441-v1'))
      ..createSync(recursive: true);
    final zip = bundledPagesArchive();
    final e = zip.findFile('050.svg.xz')!;
    File(p.join(pages.path, e.name)).writeAsBytesSync(e.content);
    File(p.join(pages.path, '.installed')).writeAsStringSync('x');
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final out = Directory('build/ui_fixes')..createSync(recursive: true);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => root.path,
    );

    Future<void> shot(
      String name,
      Widget home, {
      required InterfaceStyle style,
      ThemeModeId mode = ThemeModeId.light,
      String? styleId,
      List<Override> extra = const [],
      bool english = false,
    }) async {
      tester.view
        ..physicalSize = phone
        ..devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        'settings.interfaceStyle': style.name,
        'settings.onboardingDone': true,
        whatsNewSeenKey: whatsNewId,
      });
      final sp = await SharedPreferences.getInstance();
      final user = UserDatabase(NativeDatabase.memory());
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              contentDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(user),
              themeRegistryProvider.overrideWithValue(registry),
              sharedPreferencesProvider.overrideWithValue(sp),
              packRootProvider.overrideWithValue(root),
              editionProvider.overrideWithValue(MushafEdition.madina1441),
              readingPositionProvider.overrideWith(
                (ref) => Stream.value(
                  ReadingPositionRow(
                    id: 1,
                    edition: MushafEdition.madina1441.name,
                    view: 'page',
                    surah: 2,
                    ayah: 255,
                    page: 42,
                    updatedAt: DateTime(2026),
                  ),
                ),
              ),
              khatmaStatusProvider.overrideWith((ref) async => null),
              srsItemsProvider.overrideWith((ref) => Stream.value(const [])),
              journeyProvider.overrideWithValue((memorized: 0, mastered: 0)),
              bookmarkSetsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              ...extra,
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(english ? 'en' : 'ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildTheme(
                style: registry.byId(styleId ?? registry.defaultStyleId),
                mode: mode,
                uiFont: UiFont.changa,
                interfaceStyle: style,
              ),
              home: LookTheme(child: home),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      final object =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await object.toImage(pixelRatio: 2);
        final d = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return d!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
    }

    Widget page() => Builder(
      builder: (context) => Material(
        color: context.tokens.colors.bg,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Consumer(
            builder: (context, ref, _) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: IlluminatedFrame(
                info: ref.watch(frameInfoProvider(50)).value,
                child: MushafPage(
                  page: 50,
                  interaction: PageInteraction(
                    selection: const {},
                    marks: const {},
                    onTap: () {},
                    onVerseLongPress: (_) {},
                    onMarkerTap: (_) {},
                    onHandleDrag: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    for (final style in InterfaceStyle.values) {
      for (final mode in [ThemeModeId.light, ThemeModeId.white]) {
        await shot(
          'home_${style.name}_${mode.name}',
          const HomeScreen(),
          style: style,
          mode: mode,
        );
      }
    }
    for (final id in ['seljuk', 'hijazi', 'simple']) {
      for (final mode in [ThemeModeId.light, ThemeModeId.white]) {
        await shot(
          'page_${id}_${mode.name}',
          page(),
          style: defaultInterfaceStyle,
          mode: mode,
          styleId: id,
        );
      }
    }
    await shot(
      'home_en',
      const HomeScreen(),
      style: defaultInterfaceStyle,
      english: true,
    );

    final sized = ModelManifest(
      id: recitationModelId,
      version: '1',
      license: 'CC-BY-4.0',
      files: [
        ModelFileSpec(
          name: 'model.onnx',
          url: Uri.parse('https://example.com/model.onnx'),
          sha256: 'x',
          bytes: 120 * 1024 * 1024,
        ),
      ],
    );
    for (final (name, manifest) in [
      ('tasmee_ready', sized),
      ('tasmee_offline', null),
    ]) {
      for (final style in InterfaceStyle.values) {
        await shot(
          '${name}_${style.name}',
          const OnboardingTasmeeScreen(),
          style: style,
          extra: [
            tasmeeManifestProvider.overrideWith((ref) async => manifest),
            tasmeeModelInfoProvider.overrideWith((ref) async => (null, 0)),
          ],
        );
      }
    }
    await tester.runAsync(db.close);
  }, skip: !run);
}
