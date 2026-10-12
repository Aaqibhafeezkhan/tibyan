import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/onboarding/onboarding_edition_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_language_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_page_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_reciter_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_style_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_tasmee_screen.dart';
import 'package:tibyan/features/settings/settings_catalog.dart';
import 'package:tibyan/features/settings/settings_screen.dart';
import 'package:tibyan/features/settings/settings_section_screen.dart';
import 'package:tibyan/features/splash/splash_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Not a test: renders the splash frames, the six first-run steps and the
/// settings grid, a section and the search, in each interface style, day
/// and night, phone and laptop, into `build/onboarding_settings/`.
/// Runs only with RENDER_ONBOARDING_SETTINGS=1.
void main() {
  final run = Platform.environment['RENDER_ONBOARDING_SETTINGS'] == '1';
  const phone = Size(393, 852);
  const laptop = Size(1440, 900);

  testWidgets('render onboarding, splash and settings', (tester) async {
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
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final out = Directory('build/onboarding_settings')
      ..createSync(recursive: true);
    addTearDown(tester.view.reset);

    Future<void> settle([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> save(String name, GlobalKey key, Size size) async {
      final object =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await object.toImage(pixelRatio: size == laptop ? 1 : 2);
        final d = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return d!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
    }

    Future<GlobalKey> mount(
      Widget screen, {
      required InterfaceStyle style,
      bool night = false,
      bool elderly = false,
      Size size = phone,
      bool done = true,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        'settings.interfaceStyle': style.name,
        'settings.elderlyMode': elderly,
        'settings.mode': night ? 'night' : 'light',
        'settings.onboardingDone': done,
        if (done) whatsNewSeenKey: whatsNewId,
      });
      final sp = await SharedPreferences.getInstance();
      final user = UserDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(user.close));
      final key = GlobalKey();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => LookTheme(child: screen),
          ),
        ],
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
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final s = ref.watch(settingsProvider);
                return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  locale: const Locale('ar'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: buildTheme(
                    style: registry.byId(s.styleId),
                    mode: night ? ThemeModeId.night : ThemeModeId.light,
                    uiFont: UiFont.changa,
                    elderly: s.elderlyMode,
                    interfaceStyle: s.interfaceStyle,
                  ),
                  builder: elderly
                      ? (context, child) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: const TextScaler.linear(1.25)),
                          child: child!,
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      );
      return key;
    }

    Future<void> shot(
      String name,
      Widget screen, {
      required InterfaceStyle style,
      bool night = false,
      bool elderly = false,
      Size size = phone,
      bool done = true,
      Future<void> Function()? then,
    }) async {
      final key = await mount(
        screen,
        style: style,
        night: night,
        elderly: elderly,
        size: size,
        done: done,
      );
      await settle();
      if (then != null) {
        await then();
        await settle();
      }
      await save(name, key, size);
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> splash(
      String tag,
      InterfaceStyle style,
      bool night,
      Size size,
    ) async {
      final key = await mount(
        const SplashScreen(),
        style: style,
        night: night,
        size: size,
      );
      for (final (ms, frame) in [
        (0, 'a'),
        (250, 'b'),
        (300, 'c'),
        (400, 'd'),
      ]) {
        await tester.pump(Duration(milliseconds: ms));
        await save('splash_${tag}_$frame', key, size);
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    }

    const steps = [
      ('1_language', OnboardingLanguageScreen()),
      ('2_style', OnboardingStyleScreen()),
      ('3_page', OnboardingPageScreen()),
      ('4_edition', OnboardingEditionScreen()),
      ('5_reciter', OnboardingReciterScreen()),
      ('6_tasmee', OnboardingTasmeeScreen()),
    ];

    for (final style in InterfaceStyle.values) {
      for (final night in [false, true]) {
        final tag = '${style.name}_${night ? 'night' : 'light'}';
        await splash(tag, style, night, phone);
        for (final (name, screen) in steps) {
          await shot(
            'onb_${name}_$tag',
            screen,
            style: style,
            night: night,
            done: false,
          );
        }
        await shot(
          'settings_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
        );
        await shot(
          'section_mushaf_$tag',
          const SettingsSectionScreen(section: SettingsSection.mushaf),
          style: style,
          night: night,
        );
        await shot(
          'search_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          then: () => tester.enterText(find.byType(TextField), 'تجويد'),
        );
        await shot(
          'section_focus_$tag',
          const SettingsSectionScreen(
            section: SettingsSection.listening,
            focus: 'sajdahTimer',
          ),
          style: style,
          night: night,
        );
        // Laptop.
        await shot(
          'laptop_settings_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          size: laptop,
        );
        await shot(
          'laptop_section_$tag',
          const SettingsSectionScreen(section: SettingsSection.appearance),
          style: style,
          night: night,
          size: laptop,
        );
        await shot(
          'laptop_onb_2_style_$tag',
          const OnboardingStyleScreen(),
          style: style,
          night: night,
          size: laptop,
          done: false,
        );
        await splash('laptop_$tag', style, night, laptop);
      }
      await shot(
        'settings_elderly_${style.name}',
        const SettingsScreen(),
        style: style,
        elderly: true,
      );
    }
    await tester.runAsync(db.close);
  }, skip: !run);
}
