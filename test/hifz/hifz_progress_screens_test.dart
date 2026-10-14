import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/hifz/data/hifz_store.dart';
import 'package:tibyan/features/hifz/data/recitation_store.dart';
import 'package:tibyan/features/hifz/domain/recitation_record.dart';
import 'package:tibyan/features/hifz/presentation/hifz_screen.dart';
import 'package:tibyan/features/hifz/presentation/progress_tabs.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/l10n/app_localizations.dart';

void main() {
  late ContentDatabase content;
  late UserDatabase user;
  late ThemeRegistry registry;

  setUpAll(() async {
    content = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    registry = await ThemeRegistry.load(rootBundle);
  });
  tearDownAll(() => content.close());
  setUp(() => user = UserDatabase(NativeDatabase.memory()));
  tearDown(() => user.close());

  Widget app(Widget home, {String locale = 'ar'}) => ProviderScope(
    overrides: [
      contentDatabaseProvider.overrideWithValue(content),
      userDatabaseProvider.overrideWithValue(user),
      editionProvider.overrideWithValue(MushafEdition.madina1441),
    ],
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(
        style: registry.byId(registry.defaultStyleId),
        mode: ThemeModeId.light,
        uiFont: UiFont.plex,
      ),
      home: home,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // Al-Ikhlas is verses 6222..6225.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await user.setVerseStrengths({'112:1': 3, '112:2': 3, '112:3': 3});
    for (var i = 0; i < 2; i++) {
      await user.saveRecitation(
        RecitationRecord(
          kind: RecitationKind.voice,
          startedAt: DateTime.now().subtract(Duration(hours: 2 + i)),
          endedAt: DateTime.now().subtract(Duration(hours: 1 + i)),
          sensitivity: 'medium',
          verses: const [
            VerseResultRecord(verse: 6222, accuracy: 1, words: 4),
            VerseResultRecord(verse: 6223, accuracy: 0.5, words: 2, wrong: 1),
          ],
          slips: const [(verse: 6223, word: 2, skipped: false)],
        ),
      );
    }
  });

  testWidgets('the tabs: progress, history, hard words and goals', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(app(const HifzScreen(tab: HifzTab.progress)));
    await settle(tester);
    expect(find.text('في المجمل'), findsOneWidget);
    expect(find.text('سورة الإخلاص'), findsOneWidget);
    // 112:3 memorized by hand, never recited.
    expect(find.textContaining('لم تُسمَّع بعد: ١'), findsOneWidget);
    // No streaks, levels or badges.
    expect(find.textContaining('متتال'), findsNothing);

    await tester.tap(find.text('السجل'));
    await settle(tester);
    expect(find.textContaining('بالصوت'), findsNWidgets(2));
    expect(find.text('الإخلاص ١–٢'), findsNWidgets(2));

    await tester.tap(find.text('الكلمات الصعبة'));
    await settle(tester);
    // The word's text comes from content.db: «ٱلصَّمَدُ».
    final words = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.startsWith('ٱلص'));
    expect(words, isNotEmpty);
    expect(find.textContaining('مرتان'), findsOneWidget);

    await tester.tap(find.text('الأهداف'));
    await settle(tester);
    expect(
      find.text('لا أهداف بعد. اختر هدفا جاهزا أو اصنع هدفك.'),
      findsOneWidget,
    );
    await tester.tap(find.text('هدف جديد'));
    await settle(tester);
    expect(find.text('جزء عمّ في شهرين'), findsOneWidget);
    expect(find.text('هدف مفتوح'), findsOneWidget);
    await tester.tap(find.text('أنشئ الهدف'));
    await settle(tester);
    final goals = await tester.runAsync(() => user.watchHifzGoals().first);
    expect(goals!.single.template, 'amma');
    expect(find.text('احفظ'), findsOneWidget);
    expect(find.text('راجع'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a session opens its summary, words from content.db', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    final uuid = (await tester.runAsync(() => user.watchRecitations().first))!
        .first
        .uuid;
    await tester.pumpWidget(app(RecitationSessionScreen(uuid: uuid)));
    await settle(tester);
    expect(find.text('ملخّص الجلسة'), findsOneWidget);
    expect(find.text('الإخلاص ١–١'), findsOneWidget);
    expect(find.textContaining('ٱلص'), findsOneWidget);
    expect(find.textContaining('حساسية المطابقة'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('English reads left to right', (tester) async {
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => user.addHifzGoal(
        HifzGoalsCompanion.insert(
          template: const Value('fixSurah'),
          rangeStart: 6222,
          rangeEnd: 6225,
          startDate: '2026-10-13',
          targetDate: const Value('2026-10-26'),
          review: const Value(true),
        ),
      ),
    );
    await tester.pumpWidget(
      app(const HifzScreen(tab: HifzTab.goals), locale: 'en'),
    );
    await settle(tester);
    expect(find.text('Fix a surah'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Fix a surah'))),
      TextDirection.ltr,
    );
    await finish(tester);
  });
}
