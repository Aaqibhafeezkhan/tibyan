import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/backup/backup.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/features/khatma/data/khatmah_book.dart';
import 'package:tibyan/features/khatma/data/khatmah_store.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/interval_set.dart';
import 'package:tibyan/features/khatma/domain/khatmah.dart';
import 'package:tibyan/features/khatma/domain/quran_index.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';

import 'support.dart';

/// A restored backup's khatma shows its progress at once: the caches are
/// rebuilt from the restored attributions and the providers worked out
/// again, without restarting the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranIndex index;
  late ThemeRegistry registry;
  setUpAll(() async {
    index = await realIndex();
    registry = await ThemeRegistry.load(rootBundle);
  });

  Future<String> backupWithProgress() async {
    final a = UserDatabase(NativeDatabase.memory());
    addTearDown(a.close);
    final store = KhatmahStore(a);
    final day = Day(2026, 10, 7);
    await store.insert(
      Khatmah(
        uuid: 'k1',
        title: 'رمضان',
        startDate: day,
        targetDate: day.add(29),
        dailyWeight: 604 / 30,
        isPrimary: true,
      ),
    );
    final at = day.start.add(const Duration(hours: 8));
    await store.putSession(
      SessionRecord(
        uuid: 's1',
        start: at,
        end: at.add(const Duration(minutes: 20)),
        ranges: IntervalSet.range(1, 148),
        pages: 21,
      ),
    );
    await store.putCredit(
      Credit(
        sessionUuid: 's1',
        khatmaUuid: 'k1',
        ranges: IntervalSet.range(1, 148),
        newWeight: index.weightOf(1, 148),
        decidedBy: DecidedBy.auto,
        day: day,
        at: at,
      ),
    );
    return Backup(a).export();
  }

  test('afterRestore rebuilds the caches and refreshes the khatma', () async {
    final text = await backupWithProgress();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final b = UserDatabase(NativeDatabase.memory());
    addTearDown(b.close);
    final c = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(b),
        themeRegistryProvider.overrideWithValue(registry),
        sharedPreferencesProvider.overrideWithValue(prefs),
        quranIndexProvider.overrideWith((ref) async => index),
      ],
    );
    addTearDown(c.dispose);
    final store = c.read(khatmahStoreProvider);

    // The app ran before the restore: its book is built.
    var books = 0;
    c.listen(khatmahBookProvider, (_, _) => books++);
    await c.read(khatmahBookProvider.future);
    final before = books;

    await Backup(b, prefs: prefs).import(text);
    expect(await store.cachedCoverage('k1'), isNull);

    await c.read(khatmaServiceProvider).afterRestore();

    final cached = await store.cachedCoverage('k1');
    expect(cached, isNotNull);
    expect(cached!.coveredWeight, closeTo(index.weightOf(1, 148), 1e-9));
    expect(await store.dailyStats('k1'), hasLength(1));
    await c.read(khatmahBookProvider.future);
    expect(books, greaterThan(before), reason: 'the book is worked out again');
  });

  test('the start does not wait for the caches', () async {
    final text = await backupWithProgress();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final b = UserDatabase(NativeDatabase.memory());
    addTearDown(b.close);
    await Backup(b, prefs: prefs).import(text);
    final store = KhatmahStore(b);
    final book = KhatmahBook(store: store, index: index);
    await book.prepare((_) => null, rebuildCaches: false);
    expect(await store.cachedCoverage('k1'), isNull);
    await book.prepare((_) => null);
    expect(await store.cachedCoverage('k1'), isNotNull);
  });
}
