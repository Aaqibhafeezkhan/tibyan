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
import 'package:tibyan/features/settings/settings_catalog.dart';
import 'package:tibyan/features/settings/settings_section_screen.dart';
import 'package:tibyan/features/settings/player_settings_screen.dart';
import 'package:tibyan/features/tafsir/tafsir_screen.dart';
import 'package:tibyan/features/khatma/presentation/journal_screen.dart';
import 'package:tibyan/features/khatma/presentation/khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/new_khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/reports_screen.dart';
import 'package:tibyan/features/mushaf/presentation/about_mushaf_screen.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/mushaf/presentation/fawasil_screen.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/go_to_page.dart';
import 'package:tibyan/features/onboarding/onboarding_edition_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_language_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_style_screen.dart';
import 'package:tibyan/features/search/search_screen.dart';
import 'package:tibyan/features/settings/storage_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

import 'package:tibyan/core/crash/crash_consent.dart';
import 'package:tibyan/features/home/home_screen.dart';
import 'package:tibyan/features/mushaf/presentation/index_screen.dart';
import 'package:tibyan/features/settings/settings_screen.dart';
import 'package:tibyan/features/settings/report/report_screen.dart';
import 'package:tibyan/features/tasbih/presentation/tasbih_screen.dart';
import 'package:tibyan/features/tasbih/presentation/tasbih_log_screen.dart';
import 'package:tibyan/features/khatma/presentation/weekly_report_screen.dart';
import 'package:tibyan/features/group_khatma/presentation/group_khatma_list_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_reciter_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_page_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_page_turn_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_tasmee_screen.dart';
import 'package:tibyan/features/share_image/share_preview_screen.dart';
import 'package:tibyan/features/share_video/share_video_screen.dart';

/// Not a test: a contact sheet of the app's screens, sheets and mushaf
/// overlays in the four colour modes × Arabic and English, plus a subset at
/// text scale 1.5 and in landscape. Runs only with RENDER_UI_REVIEW=1;
/// pictures go to UI_REVIEW_OUT (default `build/ui_review`), and UI_REVIEW_ONLY
/// limits it to names containing one of its comma-separated words.
void main() {
  final run = Platform.environment['RENDER_UI_REVIEW'] == '1';
  const phone = Size(393, 852);
  const landscape = Size(852, 393);
  final only = Platform.environment['UI_REVIEW_ONLY']?.split(',');
  final outPath = Platform.environment['UI_REVIEW_OUT'] ?? 'build/ui_review';

  testWidgets(
    'render the ui review contact sheet',
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
      final out = Directory(outPath)..createSync(recursive: true);
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
        Widget Function() home, {
        ThemeModeId mode = ThemeModeId.light,
        bool english = false,
        double scale = 1,
        Size size = phone,
        Future<void> Function(BuildContext context)? overlay,
      }) async {
        if (only != null && !only.any(name.contains)) return;
        if (File('${out.path}/$name.png').existsSync()) return;
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        SharedPreferences.setMockInitialValues({
          'settings.interfaceStyle': defaultInterfaceStyle.name,
          'settings.mode': mode.name,
          'settings.language': english ? 'en' : 'ar',
          'settings.onboardingDone': true,
          whatsNewSeenKey: whatsNewId,
        });
        final sp = await SharedPreferences.getInstance();
        final user = UserDatabase(NativeDatabase.memory());
        final key = GlobalKey();
        final app = MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(english ? 'en' : 'ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: mode,
            uiFont: UiFont.changa,
            elderly: false,
            interfaceStyle: defaultInterfaceStyle,
          ),
          builder: scale == 1
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
          home: LookTheme(child: home()),
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
          unawaited(overlay(context));
          await settle();
          await tester.pump(const Duration(seconds: 1));
          await settle();
        }
        final object =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await object.toImage(pixelRatio: 1.5);
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        });
        File('${out.path}/$name.png').writeAsBytesSync(bytes!);
        await tester.pumpWidget(const SizedBox());
        // Not closed: a screen's open query would hold the close forever.
      }

      Widget about() => const AboutMushafScreen();
      final range = [for (var a = 1; a <= 3; a++) (surah: 1, ayah: a)];
      final screens =
          <(String, Widget Function(), Future<void> Function(BuildContext)?)>[
            ('home', () => const HomeScreen(), null),
            ('index_surahs', () => const IndexScreen(surah: 2), null),
            (
              'index_juz',
              () => const IndexScreen(tab: IndexTab.juz, juz: 3),
              null,
            ),
            ('index_hizb', () => const IndexScreen(tab: IndexTab.hizb), null),
            (
              'index_pages',
              () => const IndexScreen(tab: IndexTab.pages, page: 42),
              null,
            ),
            (
              'index_fawasil',
              () => const IndexScreen(tab: IndexTab.fawasil),
              null,
            ),
            ('search', () => const SearchScreen(), null),
            ('settings', () => const SettingsScreen(), null),
            for (final s in SettingsSection.values)
              (
                'settings_${s.name}',
                () => SettingsSectionScreen(section: s),
                null,
              ),
            ('player_settings', () => const PlayerSettingsScreen(), null),
            ('tafsir', () => const TafsirScreen(surah: 2, ayah: 255), null),
            ('khatma', () => const KhatmaScreen(), null),
            ('khatma_wizard', () => const NewKhatmaScreen(), null),
            ('group_khatma', () => const GroupKhatmaListScreen(), null),
            ('hifz', () => const HifzScreen(), null),
            ('hifz_map', () => const HifzMapScreen(), null),
            ('tasbih', () => const TasbihScreen(), null),
            ('tasbih_log', () => const TasbihLogScreen(), null),
            ('weekly_report', () => const WeeklyReportScreen(), null),
            ('reports', () => const ReportsScreen(), null),
            ('journal', () => const JournalScreen(), null),
            ('problem_report', () => const ReportScreen(), null),
            ('whats_new', about, showWhatsNew),
            ('onb_1_language', () => const OnboardingLanguageScreen(), null),
            ('onb_2_style', () => const OnboardingStyleScreen(), null),
            ('onb_3_edition', () => const OnboardingEditionScreen(), null),
            ('onb_4_page', () => const OnboardingPageScreen(), null),
            ('onb_5_page_turn', () => const OnboardingPageTurnScreen(), null),
            ('onb_6_reciter', () => const OnboardingReciterScreen(), null),
            ('onb_7_tasmee', () => const OnboardingTasmeeScreen(), null),
            ('share_image', about, (c) => showSharePreview(c, range)),
            ('share_video', about, (c) => showShareVideo(c, range)),
            ('fawasil', () => const FawasilScreen(), null),
            ('downloads', () => const DownloadsCenterScreen(), null),
            ('storage', () => const StorageScreen(), null),
            ('audio_downloads', () => const AudioDownloadsScreen(), null),
            (
              'crash_consent',
              about,
              (c) => showCrashConsent(c, suggestAgree: false),
            ),
            ('about', about, null),
            ('go_to_page', about, (c) => showGoToPage(c, current: 42)),
            ('assistant', () => const AssistantScreen(), null),
            ('tajweed_marks', () => const TajweedMarksScreen(), null),
          ];

      for (final (name, screen, overlay) in screens) {
        for (final english in [false, true]) {
          for (final mode in ThemeModeId.values) {
            await shot(
              '${name}__${english ? 'en' : 'ar'}_${mode.name}',
              screen,
              mode: mode,
              english: english,
              overlay: overlay,
            );
          }
        }
      }
      const subset = {
        'home',
        'index_surahs',
        'settings',
        'khatma',
        'hifz',
        'tasbih',
        'weekly_report',
        'search',
        'tafsir',
        'onb_3_edition',
        'crash_consent',
      };
      for (final (name, screen, overlay) in screens) {
        if (!subset.contains(name)) continue;
        for (final english in [false, true]) {
          final l = english ? 'en' : 'ar';
          await shot(
            '${name}__${l}_scale15',
            screen,
            english: english,
            scale: 1.5,
            overlay: overlay,
          );
          await shot(
            '${name}__${l}_landscape',
            screen,
            english: english,
            size: landscape,
            overlay: overlay,
          );
        }
      }
      await tester.pump(const Duration(minutes: 5));
      await tester.runAsync(db.close);
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
