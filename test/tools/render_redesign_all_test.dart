import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/hifz/hifz_providers.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/assistant/assistant_screen.dart';
import 'package:tibyan/features/assistant/tajweed_marks_screen.dart';
import 'package:tibyan/features/audio/audio_downloads_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_map_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_screen.dart';
import 'package:tibyan/features/reading/continuous_screen.dart';
import 'package:tibyan/features/reading/one_verse_screen.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';
import 'package:tibyan/features/settings/settings_section_screen.dart';
import 'package:tibyan/features/settings/player_settings_screen.dart';
import 'package:tibyan/features/tafsir/tafsir_screen.dart';
import 'package:tibyan/features/khatma/presentation/journal_screen.dart';
import 'package:tibyan/features/khatma/presentation/khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/new_khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/reports_screen.dart';
import 'package:tibyan/features/mushaf/data/mushaf_repository.dart';
import 'package:tibyan/features/mushaf/presentation/about_mushaf_screen.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/mushaf/presentation/fawasil_screen.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/go_to_page.dart';
import 'package:tibyan/features/onboarding/onboarding_edition_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_language_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_style_screen.dart';
import 'package:tibyan/features/sajdah/sajdah_card.dart';
import 'package:tibyan/features/search/search_screen.dart';
import 'package:tibyan/features/settings/storage_screen.dart';
import 'package:tibyan/features/share_image/share_document.dart';
import 'package:tibyan/features/share_image/share_palette.dart';
import 'package:tibyan/features/share_image/share_source.dart';
import 'package:tibyan/features/splash/splash_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Not a test: renders the app's other screens, sheets and cards in each
/// interface style into `build/redesign_all/`, with sample shared
/// pictures. Runs only with RENDER_REDESIGN_ALL=1; REDESIGN_ONLY limits it
/// to names containing one of its comma-separated words.
void main() {
  final run = Platform.environment['RENDER_REDESIGN_ALL'] == '1';
  const phone = Size(393, 852);
  const laptop = Size(1440, 900);
  final only = Platform.environment['REDESIGN_ONLY']?.split(',');

  testWidgets(
    'render the restyled screens',
    (tester) async {
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
      final db = ContentDatabase(
        NativeDatabase(
          File('assets/db/content.db'),
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
        ),
      );
      final root = Directory.systemTemp.createTempSync('render');
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      final out = Directory('build/redesign_all')..createSync(recursive: true);
      addTearDown(tester.view.reset);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => root.path,
      );

      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
        }
      }

      Future<void> shot(
        String name,
        Widget home, {
        required InterfaceStyle style,
        bool night = false,
        bool english = false,
        bool elderly = false,
        Size size = phone,
        Future<void> Function(BuildContext context)? overlay,
      }) async {
        if (only != null && !only.any(name.contains)) return;
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        SharedPreferences.setMockInitialValues({
          'settings.interfaceStyle': style.name,
          'settings.elderlyMode': elderly,
          'settings.onboardingDone': true,
          whatsNewSeenKey: whatsNewId,
        });
        final sp = await SharedPreferences.getInstance();
        final user = UserDatabase(NativeDatabase.memory());
        final key = GlobalKey();
        final mode = night ? ThemeModeId.night : ThemeModeId.light;
        Widget app = MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(english ? 'en' : 'ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: mode,
            uiFont: UiFont.changa,
            elderly: elderly,
            interfaceStyle: style,
          ),
          builder: elderly
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.25)),
                  child: child!,
                )
              : null,
          home: LookTheme(child: home),
        );
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
              ],
              child: app,
            ),
          ),
        );
        await settle();
        if (overlay != null) {
          final context = tester.element(find.byType(Scaffold).first);
          // Not awaited: the overlay stays open for the picture.
          overlay(context);
          await settle();
          await tester.pump(const Duration(seconds: 1));
        }
        final object =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await object.toImage(
            pixelRatio: size == laptop ? 1 : 2,
          );
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        });
        File('${out.path}/$name.png').writeAsBytesSync(bytes!);
        await tester.pumpWidget(const SizedBox());
        // Not closed: a screen's open query would hold the close forever.
      }

      final screens = <(String, Widget)>[
        ('splash', const SplashScreen(duration: Duration(hours: 1))),
        ('onboarding_language', const OnboardingLanguageScreen()),
        ('onboarding_style', const OnboardingStyleScreen()),
        ('onboarding_edition', const OnboardingEditionScreen()),
        ('khatma', const KhatmaScreen()),
        ('khatma_wizard', const NewKhatmaScreen()),
        ('reports', const ReportsScreen()),
        ('journal', const JournalScreen()),
        ('assistant', const AssistantScreen()),
        ('tajweed_marks', const TajweedMarksScreen()),
        ('fawasil', const FawasilScreen()),
        ('search', const SearchScreen()),
        ('downloads', const DownloadsCenterScreen()),
        ('storage', const StorageScreen()),
        ('audio_downloads', const AudioDownloadsScreen()),
        ('about', const AboutMushafScreen()),
        ('hifz', const HifzScreen()),
        ('hifz_map', const HifzMapScreen()),
        (
          'appearance',
          const SettingsSectionScreen(section: SettingsSection.mushaf),
        ),
        ('player_settings', const PlayerSettingsScreen()),
        ('continuous', const ContinuousScreen(surah: 2, ayah: 1)),
        ('one_verse', const OneVerseScreen(surah: 2, ayah: 255)),
        ('tafsir', const TafsirScreen(surah: 2, ayah: 255)),
      ];
      final sajdah = Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (context) =>
                    ColoredBox(color: context.tokens.colors.bg),
              ),
            ),
            const Center(child: SajdahCardView(seconds: 30)),
          ],
        ),
      );
      Future<void> goTo(BuildContext context) =>
          showGoToPage(context, current: 42);

      for (final style in InterfaceStyle.values) {
        for (final night in [false, true]) {
          final tag = '${style.name}_${night ? 'night' : 'light'}';
          for (final (name, screen) in screens) {
            await shot('${name}_$tag', screen, style: style, night: night);
          }
          await shot('sajdah_$tag', sajdah, style: style, night: night);
          await shot(
            'go_to_page_$tag',
            const AboutMushafScreen(),
            style: style,
            night: night,
            overlay: goTo,
          );
        }
      }
      const d = defaultInterfaceStyle;
      for (final night in [false, true]) {
        final tag = night ? 'night' : 'light';
        for (final (name, screen) in screens.skip(4).take(6)) {
          await shot(
            'laptop_${name}_$tag',
            screen,
            style: d,
            night: night,
            size: laptop,
          );
        }
      }
      await shot(
        'elderly_khatma',
        const KhatmaScreen(),
        style: d,
        elderly: true,
      );
      await shot(
        'en_assistant',
        const AssistantScreen(),
        style: d,
        english: true,
      );
      await shot(
        'en_khatma_wizard',
        const NewKhatmaScreen(),
        style: d,
        english: true,
      );

      // Sample shared pictures in each style's colours, and the original.
      if (only == null || only.any('share'.contains)) {
        await tester.runAsync(() async {
          final repo = MushafRepository(db);
          final surahs = await repo.surahs();
          final codec = await ui.instantiateImageCodec(
            File('assets/ornaments/share_logo.png').readAsBytesSync(),
          );
          final logo = (await codec.getNextFrame()).image;
          final range = [for (var a = 1; a <= 5; a++) (surah: 2, ayah: a)];
          Future<void> draw(String name, SharePalette palette) async {
            final passage = await hafsPassage(
              repo: repo,
              range: range,
              surahs: surahs,
              options: ShareOptions(divineNames: true, darkPaper: palette.dark),
            );
            final doc = ShareDocument.build(
              passage,
              logo: logo,
              palette: palette,
            );
            File('${out.path}/$name.png').writeAsBytesSync(await doc.png(0));
            doc.dispose();
          }

          for (final style in InterfaceStyle.values) {
            for (final night in [false, true]) {
              await draw(
                'share_${style.name}_${night ? 'night' : 'light'}',
                sharePaletteOf(UiLook.of(style, night: night)),
              );
            }
          }
          await draw('share_brand', SharePalette.brand);
        });
      }
      // Let the reading screens' timers run out.
      await tester.pump(const Duration(minutes: 5));
      await tester.runAsync(db.close);
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
