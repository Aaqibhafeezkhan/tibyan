import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/khatma/data/khatmah_book.dart';
import 'package:tibyan/features/khatma/data/khatmah_store.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/khatmah.dart';
import 'package:tibyan/features/khatma/domain/quran_index.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/khatma/presentation/reader_khatma.dart';
import 'package:tibyan/l10n/app_localizations.dart';

import 'support.dart';

late QuranIndex _index;
late ThemeRegistry _themes;
late AppLocalizations _en;

/// A primary khatma with nothing read yet, counted as [counting].
Future<KhatmaStatus> _status(CountingMode counting) async {
  final now = DateTime.now();
  final today = Day.logical(now, 3);
  final db = UserDatabase(NativeDatabase.memory());
  try {
    final store = KhatmahStore(db);
    final book = KhatmahBook(
      store: store,
      index: _index,
      clock: () => now,
      newUuid: () => 'banner-${counting.name}',
    );
    await book.create(
      Khatmah(
        uuid: 'banner-${counting.name}',
        title: 'Plan',
        dailyWeight: 20,
        startDate: today,
        targetDate: today.add(29),
        isPrimary: true,
        counting: counting,
        createdAt: now,
      ),
    );
    return (await statusOf(
      book,
      today,
      MushafEdition.madina1441,
      _index.madina1441,
      khatmah: await store.byUuid('banner-${counting.name}'),
    ))!;
  } finally {
    await db.close();
  }
}

Widget _app(SharedPreferences prefs, KhatmaStatus status, Widget child) =>
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        themeRegistryProvider.overrideWithValue(_themes),
        readerWirdProvider.overrideWithValue((
          status: status,
          read: 0,
          total: 20,
        )),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(
          style: _themes.byId(_themes.defaultStyleId),
          mode: ThemeModeId.light,
          uiFont: UiFont.changa,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _index = await realIndex();
    _themes = await ThemeRegistry.load(rootBundle);
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('«Later» puts the banner away for the day, after a restart '
      'too', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final status = (await tester.runAsync(
      () => _status(CountingMode.wirdConfirm),
    ))!;
    final last = lastWirdPageOf(status)!;
    Widget banner() => WirdCompletionBanner(shownPages: [last], allowed: true);

    await tester.pumpWidget(_app(prefs, status, banner()));
    expect(find.text(_en.wirdEndOfPortion), findsOneWidget);
    await tester.tap(find.text(_en.wirdLater));
    await tester.pump();
    expect(find.text(_en.wirdEndOfPortion), findsNothing);

    // The app again, from the saved preferences.
    await tester.pumpWidget(const SizedBox());
    final again = await SharedPreferences.getInstance();
    await tester.pumpWidget(_app(again, status, banner()));
    expect(find.text(_en.wirdEndOfPortion), findsNothing);

    // Another day's portion is asked about again.
    await prefs.setString('khatma.wirdBannerDismissed', 'other_2000-01-01');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(prefs, status, banner()));
    expect(find.text(_en.wirdEndOfPortion), findsOneWidget);
  });

  testWidgets('the reader asks to confirm the portion only when the khatma '
      'counts that way', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (mode, shown) in [
      (CountingMode.wirdConfirm, true),
      (CountingMode.auto, false),
      (CountingMode.ask, false),
      (CountingMode.manual, false),
    ]) {
      final status = (await tester.runAsync(() => _status(mode)))!;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(prefs, status, const WirdIndicator()));
      expect(
        find.text(_en.wirdConfirmDone),
        shown ? findsOneWidget : findsNothing,
        reason: mode.name,
      );
    }
  });
}
