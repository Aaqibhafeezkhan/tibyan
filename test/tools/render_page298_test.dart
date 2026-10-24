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
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/illuminated_frame.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/page_interaction.dart';
import 'package:tibyan/features/mushaf/data/tajweed.dart';
import 'package:tibyan/l10n/app_localizations.dart';

import '../testing/bundled_pages.dart';

/// Not a test: renders Madina 1441 page 298 (Al-Kahf 18:42, «كَفَّيْهِ»)
/// in every theme mode, with and without tajweed and divine-name colours,
/// into `build/page298/`. Runs only with RENDER_PAGE298=1. PAGE298_TALL=1
/// renders at a 20:9 phone (1080x2400 at 2.625), where the lines are
/// spread apart and each is drawn in its own band.
void main() {
  final run = Platform.environment['RENDER_PAGE298'] == '1';
  final tall = Platform.environment['PAGE298_TALL'] == '1';
  final phone = tall ? const Size(1080, 2400) : const Size(700, 1100);

  testWidgets('render page 298', (tester) async {
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
    final e = zip.findFile('298.svg.xz')!;
    File(p.join(pages.path, e.name)).writeAsBytesSync(e.content);
    File(p.join(pages.path, '.installed')).writeAsStringSync('x');
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final out = Directory('build/page298')..createSync(recursive: true);
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
      Map<String, Object> prefs = const {},
    }) async {
      tester.view
        ..physicalSize = phone
        ..devicePixelRatio = tall ? 2.625 : 1;
      SharedPreferences.setMockInitialValues({
        'settings.interfaceStyle': style.name,
        'settings.onboardingDone': true,
        whatsNewSeenKey: whatsNewId,
        ...prefs,
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
                info: ref.watch(frameInfoProvider(298)).value,
                child: MushafPage(
                  page: 298,
                  interaction: PageInteraction(
                    selection: const {},
                    marks: const {},
                    onTap: () {},
                    onVerseLongPress: (_) {},
                    onMarkerTap: (_) {},
                    onHandleDrag: (_, _) {},
                    tajweedColor: ref.watch(settingsProvider).tajweedColors
                        ? (rule) => tajweedHueOf(
                            rule,
                            const {},
                          )?.on(darkPaper: !context.tokens.mode.isLight)
                        : null,
                    tajweed: ref.watch(settingsProvider).tajweedColors
                        ? ref.watch(tajweedPageProvider(298)).value ?? ''
                        : '',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    for (final id in ['simple', 'zakhrafa']) {
      for (final mode in ThemeModeId.values) {
        for (final (tag, prefs) in [
          ('plain', <String, Object>{}),
          ('tajweed', <String, Object>{'settings.tajweedColors': true}),
          ('divine', <String, Object>{'settings.highlightDivineNames': true}),
        ]) {
          await shot(
            'p298_${id}_${mode.name}_$tag',
            page(),
            style: defaultInterfaceStyle,
            mode: mode,
            styleId: id,
            prefs: prefs,
          );
        }
      }
    }
    await tester.runAsync(db.close);
  }, skip: !run);
}
