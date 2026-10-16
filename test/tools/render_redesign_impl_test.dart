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
import 'package:tibyan/features/home/home_screen.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/index_screen.dart';
import 'package:tibyan/features/settings/settings_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Not a test: renders the real Home, Index and Settings screens and the
/// app's overlays in each interface style into `build/redesign_impl/`.
/// Runs only with RENDER_REDESIGN_IMPL=1.
void main() {
  final run = Platform.environment['RENDER_REDESIGN_IMPL'] == '1';
  const phone = Size(393, 852);
  const laptop = Size(1440, 900);

  testWidgets('render the redesigned screens', (tester) async {
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
    final out = Directory('build/redesign_impl')..createSync(recursive: true);
    addTearDown(tester.view.reset);

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
        home: home,
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
      }
      final object =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await object.toImage(pixelRatio: size == laptop ? 1 : 2);
        final d = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return d!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(user.close);
    }

    Future<void> dialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.backupImport),
          content: Text(l.backupImportHint),
          actions: [
            TextButton(
              onPressed: () {},
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(onPressed: () {}, child: Text(l.backupImport)),
          ],
        );
      },
    );

    Future<void> snack(BuildContext context) async {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.backupDone('١٢', '٣')),
          action: SnackBarAction(label: l.whatsNewDone, onPressed: () {}),
          duration: const Duration(minutes: 1),
        ),
      );
    }

    Future<void> menu(BuildContext context) => showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 120, 16, 0),
      items: [
        for (final (i, t) in [
          AppLocalizations.of(context).tabSurahs,
          AppLocalizations.of(context).tabJuz,
          AppLocalizations.of(context).tabHizb,
        ].indexed)
          PopupMenuItem(value: i, child: Text(t)),
      ],
    );

    for (final style in InterfaceStyle.values) {
      for (final night in [false, true]) {
        final tag = '${style.name}_${night ? 'night' : 'light'}';
        await shot('home_$tag', const HomeScreen(), style: style, night: night);
        await shot(
          'index_$tag',
          const IndexScreen(surah: 2),
          style: style,
          night: night,
        );
        await shot(
          'settings_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
        );
        await shot(
          'whatsnew_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          overlay: showWhatsNew,
        );
        await shot(
          'dialog_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          overlay: dialog,
        );
        await shot(
          'snackbar_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          overlay: snack,
        );
        await shot(
          'menu_$tag',
          const SettingsScreen(),
          style: style,
          night: night,
          overlay: menu,
        );
      }
    }
    const d = defaultInterfaceStyle;
    for (final night in [false, true]) {
      final tag = night ? 'night' : 'light';
      await shot(
        'laptop_home_$tag',
        const HomeScreen(),
        style: d,
        night: night,
        size: laptop,
      );
      await shot(
        'laptop_index_$tag',
        const IndexScreen(surah: 2),
        style: d,
        night: night,
        size: laptop,
      );
      await shot(
        'laptop_settings_$tag',
        const SettingsScreen(),
        style: d,
        night: night,
        size: laptop,
      );
    }
    await shot('elderly_home', const HomeScreen(), style: d, elderly: true);
    await shot(
      'elderly_index',
      const IndexScreen(surah: 2),
      style: d,
      elderly: true,
    );
    await shot(
      'elderly_settings',
      const SettingsScreen(),
      style: d,
      elderly: true,
    );
    // English (left to right): every arrow must point the other way.
    await shot('en_home', const HomeScreen(), style: d, english: true);
    await shot(
      'en_index',
      const IndexScreen(surah: 2),
      style: d,
      english: true,
    );
    await shot('en_settings', const SettingsScreen(), style: d, english: true);
    await tester.runAsync(db.close);
  }, skip: !run);
}
