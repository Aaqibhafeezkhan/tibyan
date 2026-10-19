import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/hifz/hifz_providers.dart';
import 'package:tibyan/features/home/home_screen.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The home screen lays out without a RenderFlex overflow on tablets and
/// desktop windows (portrait and landscape), at larger text, in every
/// interface style, in elderly mode, ar and en.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentDatabase db;
  late Directory root;
  late ThemeRegistry registry;
  setUpAll(() async {
    db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    root = Directory.systemTemp.createTempSync('home_tablet');
    registry = await ThemeRegistry.load(rootBundle);
  });
  tearDownAll(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required InterfaceStyle style,
    required bool elderly,
    required bool english,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'app.whatsNewSeen': 'all',
      'settings.interfaceStyle': style.name,
      'settings.elderlyMode': elderly,
    });
    final sp = await SharedPreferences.getInstance();
    final user = UserDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(user.close));
    // The view's size (what MediaQuery reports), not just the surface's:
    // the screen picks its layout from MediaQuery.
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDatabaseProvider.overrideWithValue(db),
          userDatabaseProvider.overrideWithValue(user),
          themeRegistryProvider.overrideWithValue(registry),
          sharedPreferencesProvider.overrideWithValue(sp),
          packRootProvider.overrideWithValue(root),
          readingPositionProvider.overrideWith((ref) => Stream.value(null)),
          khatmaStatusProvider.overrideWith((ref) async => null),
          srsItemsProvider.overrideWith((ref) => Stream.value(const [])),
          journeyProvider.overrideWithValue((memorized: 0, mastered: 0)),
          bookmarkSetsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          locale: Locale(english ? 'en' : 'ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: ThemeModeId.light,
            uiFont: UiFont.changa,
            interfaceStyle: style,
            elderly: elderly,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  for (final size in const [
    Size(768, 1024),
    Size(1024, 768),
    Size(820, 1180),
    Size(1180, 820),
    Size(1024, 1366),
    Size(1366, 1024),
    Size(1440, 900),
  ]) {
    for (final scale in const [1.0, 1.3]) {
      for (final english in [false, true]) {
        for (final elderly in [false, true]) {
          final tag =
              '${size.width.toInt()}x${size.height.toInt()} '
              'x$scale ${english ? 'en' : 'ar'}${elderly ? ' elderly' : ''}';
          testWidgets('home fits a tablet: $tag', (tester) async {
            for (final style in InterfaceStyle.values) {
              await pump(
                tester,
                size: size,
                scale: scale,
                style: style,
                elderly: elderly,
                english: english,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '${style.name} $tag',
              );
              // Scroll through the whole list so every tile is laid out.
              final list = find.byType(Scrollable).first;
              await tester.drag(
                list,
                const Offset(0, -3000),
                warnIfMissed: false,
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: '${style.name} $tag (scrolled)',
              );
            }
          });
        }
      }
    }
  }
}
