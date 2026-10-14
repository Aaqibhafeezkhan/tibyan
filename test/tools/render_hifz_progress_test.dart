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
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/l10n/app_localizations.dart';
import 'package:tibyan/features/onboarding/onboarding_edition_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_language_screen.dart';
import 'package:tibyan/features/onboarding/onboarding_style_screen.dart';

import 'package:drift/drift.dart' show Value;
import 'package:tibyan/features/hifz/data/hifz_store.dart';
import 'package:tibyan/features/hifz/data/recitation_store.dart';
import 'package:tibyan/features/hifz/domain/recitation_record.dart';
import 'package:tibyan/features/hifz/presentation/hifz_map_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_screen.dart';
import 'package:tibyan/features/hifz/presentation/progress_tabs.dart';
import 'package:tibyan/features/home/home_screen.dart';

/// Not a test: renders the onboarding headers (the «تبيان» wordmark) and the
/// hifz progress screens in each interface style into
/// `build/<RENDER_OUT or hifz_progress>/`. Runs only with RENDER_HIFZ=1.
void main() {
  final run = Platform.environment['RENDER_HIFZ'] == '1';
  final only = Platform.environment['RENDER_ONLY'] ?? '';
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
    final out = Directory(
      'build/${Platform.environment['RENDER_OUT'] ?? 'hifz_progress'}',
    )..createSync(recursive: true);
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
      bool seeded = false,
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
      if (seeded) await tester.runAsync(() => seed(user));
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
        final image = await object.toImage(pixelRatio: size == laptop ? 1 : 2);
        final d = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return d!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await settle();
      await tester.runAsync(user.close);
    }

    if (only.isEmpty || only == 'onboarding') {
      for (final style in InterfaceStyle.values) {
        for (final night in [false, true]) {
          final tag = '${style.name}_${night ? 'night' : 'light'}';
          await shot(
            'onb_language_$tag',
            const OnboardingLanguageScreen(),
            style: style,
            night: night,
          );
          await shot(
            'onb_style_$tag',
            const OnboardingStyleScreen(),
            style: style,
            night: night,
          );
          await shot(
            'onb_edition_$tag',
            const OnboardingEditionScreen(),
            style: style,
            night: night,
          );
        }
      }
    }
    if (only.isEmpty || only == 'hifz') {
      final screens = <String, Widget Function()>{
        'progress': () => const HifzScreen(tab: HifzTab.progress),
        'history': () => const HifzScreen(tab: HifzTab.history),
        'hardwords': () => const HifzScreen(tab: HifzTab.hardWords),
        'goals': () => const HifzScreen(tab: HifzTab.goals),
        'session': () => const _NewestSession(),
        'map': () => const HifzMapScreen(),
        'home': () => const HomeScreen(),
      };
      for (final style in InterfaceStyle.values) {
        for (final night in [false, true]) {
          final tag = '${style.name}_${night ? 'night' : 'light'}';
          for (final e in screens.entries) {
            await shot(
              '${e.key}_$tag',
              e.value(),
              style: style,
              night: night,
              seeded: true,
            );
          }
        }
      }
      for (final night in [false, true]) {
        final tag = night ? 'night' : 'light';
        for (final e in ['progress', 'goals', 'history']) {
          await shot(
            'laptop_${e}_$tag',
            screens[e]!(),
            style: defaultInterfaceStyle,
            night: night,
            size: laptop,
            seeded: true,
          );
        }
      }
      await shot(
        'en_progress_light',
        const HifzScreen(tab: HifzTab.progress),
        style: defaultInterfaceStyle,
        english: true,
        seeded: true,
      );
      await shot(
        'en_goals_light',
        const HifzScreen(tab: HifzTab.goals),
        style: defaultInterfaceStyle,
        english: true,
        seeded: true,
      );
      await shot(
        'elderly_progress_light',
        const HifzScreen(tab: HifzTab.progress),
        style: defaultInterfaceStyle,
        elderly: true,
        seeded: true,
      );
      await shot(
        'elderly_goals_light',
        const HifzScreen(tab: HifzTab.goals),
        style: defaultInterfaceStyle,
        elderly: true,
        seeded: true,
      );
    }
    await tester.runAsync(db.close);
  }, skip: !run);
}

/// Sample progress: Juz ʿAmma's last surahs memorized, some recited.
Future<void> seed(UserDatabase db) async {
  final now = DateTime.now();
  final strengths = <String, int>{};
  // Al-Mulk (67) by hand; the last 14 surahs (101..114) memorized.
  for (var a = 1; a <= 30; a++) {
    strengths['67:$a'] = 3;
  }
  const counts = {
    101: 11,
    102: 8,
    103: 3,
    104: 9,
    105: 5,
    106: 4,
    107: 7,
    108: 3,
    109: 6,
    110: 3,
    111: 5,
    112: 4,
    113: 5,
    114: 6,
  };
  for (final e in counts.entries) {
    for (var a = 1; a <= e.value; a++) {
      strengths['${e.key}:$a'] = 3;
    }
  }
  await db.setVerseStrengths(strengths);
  // Ids: an-Nas 6231..6236, al-Falaq 6226..6230, al-Ikhlas 6222..6225,
  // al-Kawthar 6205..6207, al-Asr 6177..6179.
  Future<void> session(
    RecitationKind kind,
    int hoursAgo,
    Map<int, double> verses, [
    List<WordSlip> slips = const [],
  ]) => db.saveRecitation(
    RecitationRecord(
      kind: kind,
      startedAt: now.subtract(Duration(hours: hoursAgo, minutes: 6)),
      endedAt: now.subtract(Duration(hours: hoursAgo)),
      sensitivity: kind == RecitationKind.voice ? 'medium' : null,
      verses: [
        for (final e in verses.entries)
          VerseResultRecord(
            verse: e.key,
            accuracy: e.value,
            words: 6,
            wrong: e.value < .9 ? 1 : 0,
          ),
      ],
      slips: slips,
    ),
  );
  for (var i = 0; i < 2; i++) {
    await session(
      RecitationKind.voice,
      70 - i * 24,
      {for (var id = 6226; id <= 6236; id++) id: id == 6229 ? .8 : 1},
      const [(verse: 6229, word: 3, skipped: false)],
    );
  }
  await session(RecitationKind.test, 30, {
    for (var id = 6222; id <= 6225; id++) id: 1,
  });
  await session(
    RecitationKind.touch,
    20,
    {6177: 1, 6178: .7, 6179: 1},
    const [(verse: 6178, word: 2, skipped: true)],
  );
  await session(
    RecitationKind.voice,
    2,
    {6205: .95, 6206: 1, 6207: .85},
    const [
      (verse: 6178, word: 2, skipped: false),
      (verse: 6207, word: 4, skipped: false),
    ],
  );
  final today = DateTime(now.year, now.month, now.day);
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  await db.addHifzGoal(
    HifzGoalsCompanion.insert(
      template: const Value('amma'),
      rangeStart: 5673,
      rangeEnd: 6236,
      startDate: key(today.subtract(const Duration(days: 10))),
      targetDate: Value(key(today.add(const Duration(days: 49)))),
      reminderTime: const Value(6 * 60),
    ),
  );
  await db.addHifzGoal(
    HifzGoalsCompanion.insert(
      template: const Value('fixSurah'),
      rangeStart: 5242,
      rangeEnd: 5271,
      startDate: key(today.subtract(const Duration(days: 2))),
      targetDate: Value(key(today.add(const Duration(days: 11)))),
      review: const Value(true),
    ),
  );
  await db.saveSrsReview(
    unit: 'surah',
    fromRef: '67:1',
    toRef: '67:30',
    stability: 4,
    difficulty: 5,
    dueAt: today,
    lapse: false,
    now: today.subtract(const Duration(days: 4)),
  );
}

/// The newest session's summary.
class _NewestSession extends ConsumerWidget {
  const _NewestSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_newest).value;
    return s == null ? const Scaffold() : RecitationSessionScreen(uuid: s);
  }
}

final _newest = FutureProvider<String?>(
  (ref) async =>
      (await ref.watch(userDatabaseProvider).watchRecitations().first)
          .firstOrNull
          ?.uuid,
);
