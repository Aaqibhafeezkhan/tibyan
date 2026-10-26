import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/sync/cloud/cloud_store.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/sync/sync_controller.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<(ProviderContainer, UserDatabase)> setUpContainer(
    CloudStore? store,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = UserDatabase(NativeDatabase.memory());
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userDatabaseProvider.overrideWithValue(db),
        cloudStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    return (c, db);
  }

  testWidgets('off by default; switching on syncs and keeps the time', (
    tester,
  ) async {
    final store = MemoryCloudStore(kind: 'icloud');
    final (c, db) = (await tester.runAsync(() => setUpContainer(store)))!;
    expect(c.read(cloudSyncProvider).enabled, isFalse);
    await tester.runAsync(() async {
      await db.addBookmarkSet(
        name: 'الكهف',
        color: 1,
        surah: 18,
        ayah: 1,
        page: 293,
      );
      expect(await c.read(cloudSyncProvider.notifier).enable(), isTrue);
      await c.read(cloudSyncProvider.notifier).syncNow();
    });
    final s = c.read(cloudSyncProvider);
    expect(s.enabled, isTrue);
    expect(s.lastSync, isNotNull);
    expect(s.phase, SyncPhase.idle);
    expect(store.files.keys.single, startsWith('tibyan-sync-'));
    // Stop and delete: the cloud is empty, the device keeps its data.
    await tester.runAsync(
      () => c.read(cloudSyncProvider.notifier).disableAndDeleteCloud(),
    );
    expect(store.files, isEmpty);
    expect(c.read(cloudSyncProvider).enabled, isFalse);
    final rows = await tester.runAsync(() => db.select(db.bookmarkSets).get());
    expect(rows, hasLength(1));
  });

  testWidgets('a build without the capability cannot switch on', (
    tester,
  ) async {
    final store = MemoryCloudStore(
      kind: 'icloud',
      down: CloudUnavailable.notInThisBuild,
    );
    final (c, _) = (await tester.runAsync(() => setUpContainer(store)))!;
    final ok = await tester.runAsync(
      () => c.read(cloudSyncProvider.notifier).enable(),
    );
    expect(ok, isFalse);
    expect(c.read(cloudSyncProvider).enabled, isFalse);
    expect(
      c.read(cloudSyncProvider).unavailable,
      CloudUnavailable.notInThisBuild,
    );
  });

  testWidgets('a failed sync is reported and does not throw', (tester) async {
    final store = MemoryCloudStore(kind: 'gdrive');
    final (c, _) = (await tester.runAsync(() => setUpContainer(store)))!;
    await tester.runAsync(() async {
      await c.read(cloudSyncProvider.notifier).enable();
      await c.read(cloudSyncProvider.notifier).syncNow();
      store.down = CloudUnavailable.noAccount;
      await c.read(cloudSyncProvider.notifier).syncNow();
    });
    expect(c.read(cloudSyncProvider).phase, SyncPhase.failed);
    expect(c.read(cloudSyncProvider).unavailable, CloudUnavailable.noAccount);
  });
}
