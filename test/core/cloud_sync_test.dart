import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/sync/cloud/cloud_store.dart';
import 'package:tibyan/core/sync/cloud/cloud_sync_engine.dart';
import 'package:tibyan/core/sync/cloud/sync_merge.dart';
import 'package:tibyan/core/sync/cloud/sync_records.dart';
import 'package:tibyan/features/tasbih/data/tasbih_repository.dart';

/// One device: its database, preferences and clock.
class _Device {
  _Device(this.id, this.store) : db = UserDatabase(NativeDatabase.memory());

  final String id;
  final CloudStore store;
  final UserDatabase db;
  final prefs = MapSyncPrefs();
  var now = DateTime(2026, 10, 1, 9);

  late final engine = CloudSyncEngine(
    db: db,
    prefs: prefs,
    store: store,
    deviceId: id,
    clock: () => now,
  );

  Future<SyncReport> sync() => engine.sync();

  void later([Duration d = const Duration(minutes: 1)]) => now = now.add(d);

  Future<List<BookmarkSetRow>> fawasil() => db.select(db.bookmarkSets).get();

  Future<int> addFasil(String name, {int surah = 2, int ayah = 1}) async {
    final id = await db
        .into(db.bookmarkSets)
        .insert(
          BookmarkSetsCompanion.insert(
            name: name,
            color: 1,
            surah: surah,
            ayah: ayah,
            page: 2,
            updatedAt: now,
          ),
        );
    return id;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MemoryCloudStore store;
  late _Device a, b;

  setUp(() {
    store = MemoryCloudStore();
    a = _Device('device-a', store);
    b = _Device('device-b', store);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('a fasil made on one device reaches the other', () async {
    await a.addFasil('الكهف');
    await a.sync();
    final r = await b.sync();
    expect(r.applied, 1);
    expect(r.changedEntities, {'bookmark_sets'});
    final got = await b.fawasil();
    expect(got.single.name, 'الكهف');
    expect(got.single.uuid, (await a.fawasil()).single.uuid);
  });

  test('syncing again with nothing new changes nothing', () async {
    await a.addFasil('الكهف');
    await a.sync();
    await b.sync();
    final writes = store.writes;
    final again = await b.sync();
    expect(again.applied, 0);
    expect(again.uploaded, isFalse);
    expect((await a.sync()).applied, 0);
    expect(store.writes, writes);
    expect(await b.fawasil(), hasLength(1));
  });

  test('a moved fasil stays one record (newest place wins)', () async {
    final id = await a.addFasil('الورد');
    await a.sync();
    await b.sync();
    a.later();
    await a.db.moveBookmarkSet(id, surah: 18, ayah: 1, page: 293);
    await a.sync();
    await b.sync();
    final got = await b.fawasil();
    expect(got, hasLength(1));
    expect(got.single.surah, 18);
  });

  test('a deletion syncs as a tombstone and is not undone', () async {
    final id = await a.addFasil('الكهف');
    await a.sync();
    await b.sync();
    await a.db.deleteBookmarkSet(id);
    a.later();
    await a.sync();
    final r = await b.sync();
    expect(r.applied, 1);
    expect(await b.fawasil(), isEmpty);
    // b's own file still lists the fasil until b writes again; a reads it
    // and keeps the deletion because the tombstone is newer.
    await a.sync();
    expect(await a.fawasil(), isEmpty);
    final journal = await a.db.select(a.db.syncJournal).get();
    expect(journal.single.deleted, isTrue);
  });

  test('a conflicting edit: the later write wins on both devices', () async {
    final id = await a.addFasil('الكهف');
    await a.sync();
    await b.sync();
    final idB = (await b.fawasil()).single.id;
    // Both rename while apart; b's rename is later.
    a.now = DateTime(2026, 10, 1, 10);
    await (a.db.update(a.db.bookmarkSets)..where((t) => t.id.equals(id))).write(
      BookmarkSetsCompanion(name: const Value('من a'), updatedAt: Value(a.now)),
    );
    b.now = DateTime(2026, 10, 1, 11);
    await (b.db.update(
      b.db.bookmarkSets,
    )..where((t) => t.id.equals(idB))).write(
      BookmarkSetsCompanion(name: const Value('من b'), updatedAt: Value(b.now)),
    );
    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.fawasil()).single.name, 'من b');
    expect((await b.fawasil()).single.name, 'من b');
  });

  test('an edit after a deletion elsewhere brings the record back', () async {
    final id = await a.addFasil('الكهف');
    await a.sync();
    await b.sync();
    a.now = DateTime(2026, 10, 1, 10);
    await a.db.deleteBookmarkSet(id);
    await a.sync();
    // b edits later, before seeing the deletion.
    b.now = DateTime(2026, 10, 1, 12);
    final idB = (await b.fawasil()).single.id;
    await (b.db.update(b.db.bookmarkSets)..where((t) => t.id.equals(idB)))
        .write(BookmarkSetsCompanion(updatedAt: Value(b.now)));
    await b.sync();
    await a.sync();
    expect(await a.fawasil(), hasLength(1));
    expect(await b.fawasil(), hasLength(1));
  });

  test('equal times settle by device id the same way everywhere', () {
    expect(isNewer(5, 'b', 5, 'a'), isTrue);
    expect(isNewer(5, 'a', 5, 'b'), isFalse);
    expect(isNewer(6, 'a', 5, 'b'), isTrue);
    final n = newestOf([
      const SyncEntry(entity: 'e', key: 'k', updatedAt: 5, deviceId: 'a'),
      const SyncEntry(
        entity: 'e',
        key: 'k',
        updatedAt: 5,
        deviceId: 'b',
        deleted: true,
      ),
    ]);
    expect(n.values.single.deviceId, 'b');
  });

  test('the four fixed marks are one record each across devices', () async {
    await a.db.setMark(
      MarkKind.reading,
      name: 'قراءة',
      surah: 2,
      ayah: 5,
      page: 3,
    );
    await b.db.setMark(
      MarkKind.reading,
      name: 'قراءة',
      surah: 1,
      ayah: 1,
      page: 1,
    );
    b.later(const Duration(hours: 1));
    // b moves its mark later than a set its own.
    await b.db.setMark(
      MarkKind.reading,
      name: 'قراءة',
      surah: 3,
      ayah: 7,
      page: 50,
    );
    await a.sync();
    await b.sync();
    await a.sync();
    final marksA = await a.fawasil();
    expect(marksA, hasLength(1));
    expect((marksA.single.surah, (await b.fawasil()).single.surah), (3, 3));
  });

  test('khatmas and hifz records sync with their keys', () async {
    await a.db
        .into(a.db.khatmas)
        .insert(
          KhatmasCompanion.insert(
            title: 'ختمة',
            edition: 'madina1441',
            startDate: '2026-10-01',
            targetDate: '2026-10-30',
            updatedAt: Value(a.now),
          ),
        );
    await a.db
        .into(a.db.memorizations)
        .insert(
          MemorizationsCompanion.insert(
            unit: 'ayah',
            ref: '2:255',
            strength: 3,
            updatedAt: Value(a.now),
          ),
        );
    await a.sync();
    final r = await b.sync();
    expect(r.changedEntities, {'khatma', 'memorization'});
  });

  test('the same dhikr on the same day adds up across devices', () async {
    final day = DateTime(2026, 10, 1, 9);
    final ra = TasbihRepository(a.db), rb = TasbihRepository(b.db);
    await ra.record('app:seen34', count: 33, rounds: 1, at: day);
    // b counts too, part of it from the watch (absorbed as a record).
    await rb.record('app:seen34', count: 10, at: day);
    await rb.record('app:seen34', count: 5, at: day);
    await a.sync();
    await b.sync();
    await a.sync();
    expect(await ra.dayCount('app:seen34', at: day), 48);
    expect(await rb.dayCount('app:seen34', at: day), 48);
    expect(await rb.dayTotal(at: day), 48);
    final log = await ra.watchLog().first;
    expect(log['2026-10-01']!['app:seen34'], (count: 48, rounds: 1));
    // Each device's own counter keeps growing on its own row.
    a.later();
    await ra.record('app:seen34', count: 2, at: day);
    await a.sync();
    await b.sync();
    expect(await rb.dayCount('app:seen34', at: day), 50);
    expect(await b.db.select(b.db.tasbihDays).get(), hasLength(2));
    // Syncing again changes nothing.
    final again = await b.sync();
    expect(again.applied, 0);
    expect(again.uploaded, isFalse);
  });

  test('tadabbur notes and the reading position sync', () async {
    await a.db
        .into(a.db.reflections)
        .insert(
          ReflectionsCompanion.insert(
            surah: 2,
            ayah: 255,
            body: 'ملاحظة',
            updatedAt: Value(a.now),
          ),
        );
    await a.db.savePosition(
      edition: 'madina1441',
      view: 'page',
      surah: 18,
      ayah: 10,
      page: 294,
    );
    await a.sync();
    final r = await b.sync();
    expect(r.changedEntities, {'reflection', 'reading_positions'});
    expect((await b.db.select(b.db.reflections).getSingle()).body, 'ملاحظة');
    final pos = (await b.db.position())!;
    expect((pos.surah, pos.ayah, pos.page), (18, 10, 294));
  });

  test('a stamp more than a day ahead counts as when it arrived', () async {
    await a.addFasil('الكهف');
    await a.sync();
    await b.sync();
    // b's clock is three days fast.
    b.now = a.now.add(const Duration(days: 3));
    await (b.db.update(b.db.bookmarkSets)).write(
      BookmarkSetsCompanion(name: const Value('ب'), updatedAt: Value(b.now)),
    );
    await b.sync();
    a.later();
    expect((await a.sync()).applied, 1);
    expect((await a.fawasil()).single.name, 'ب');
    // Arriving again does not apply it again.
    a.later();
    final again = await a.sync();
    expect((again.applied, again.uploaded), (0, false));
    // A later edit on a (right clock) wins over b's skewed stamp.
    a.later();
    await (a.db.update(a.db.bookmarkSets)).write(
      BookmarkSetsCompanion(name: const Value('أ'), updatedAt: Value(a.now)),
    );
    await a.sync();
    a.later();
    await a.sync();
    expect((await a.fawasil()).single.name, 'أ');
  });

  test(
    'synced settings: chosen keys only, first sync adopts the cloud',
    () async {
      a.prefs.values['settings.style'] = 'zakhrafa';
      a.prefs.values['settings.edition'] = 'shamarly';
      await a.sync();
      // b has its own (default) style before its first sync.
      b.prefs.values['settings.style'] = 'plain';
      await b.sync();
      expect(b.prefs.values['settings.style'], 'zakhrafa');
      expect(b.prefs.values.containsKey('settings.edition'), isFalse);
      // A later choice on b goes to a.
      b.later();
      b.prefs.values['settings.style'] = 'night';
      await b.sync();
      a.later(const Duration(minutes: 2));
      await a.sync();
      expect(a.prefs.values['settings.style'], 'night');
    },
  );

  test('a file from a newer app or a damaged file is skipped', () async {
    store.files['tibyan-sync-x.json'] = '{"app":"tibyan-sync","format":99}';
    store.files['tibyan-sync-y.json'] = 'not json';
    await a.addFasil('الكهف');
    final r = await a.sync();
    expect(r.applied, 0);
    expect(r.uploaded, isTrue);
    expect(
      SyncFile.decode(store.files['tibyan-sync-device-a.json']!),
      isNotNull,
    );
  });

  test('a row missing a needed column is left out, not half written', () async {
    store.files[SyncFile.nameFor('z')] = SyncFile(
      deviceId: 'z',
      writtenAt: 1,
      entries: [
        SyncEntry(
          entity: 'bookmark_sets',
          key: SyncRecords.keyOf('bookmark_sets', {'uuid': 'u1'})!,
          updatedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
          deviceId: 'z',
          row: const {'uuid': 'u1', 'name': 'ناقص'},
        ),
      ],
    ).encode();
    final r = await a.sync();
    expect(r.applied, 0);
    expect(await a.fawasil(), isEmpty);
  });

  test('forget clears the journal and leaves the rows', () async {
    await a.addFasil('الكهف');
    await a.sync();
    await a.engine.forget();
    expect(await a.db.select(a.db.syncJournal).get(), isEmpty);
    expect(await a.fawasil(), hasLength(1));
  });

  test('a version 7 database gains fasil ids and the journal', () async {
    final dir = Directory.systemTemp.createTempSync('sync_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/user.db');
    final fresh = UserDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.close();
    // As version 7 left it: fawasil without ids, no journal.
    final raw = sqlite3.open(file.path)
      ..execute('DROP TABLE sync_journal')
      ..execute('DROP TABLE bookmark_sets')
      ..execute(
        'CREATE TABLE bookmark_sets (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, color INTEGER NOT NULL, surah INTEGER NOT NULL, '
        'ayah INTEGER NOT NULL, page INTEGER NOT NULL, sort_order INTEGER '
        'NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, kind TEXT NULL)',
      )
      ..execute(
        'INSERT INTO bookmark_sets (name, color, surah, ayah, page, '
        "updated_at) VALUES ('الكهف', 1, 18, 1, 293, 1), "
        "('يس', 1, 36, 1, 440, 1)",
      )
      ..execute('PRAGMA user_version = 7');
    raw.close();
    final db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.select(db.bookmarkSets).get();
    expect(rows.map((r) => r.uuid), everyElement(isNotNull));
    expect(rows.map((r) => r.uuid).toSet(), hasLength(2));
    expect(await db.select(db.syncJournal).get(), isEmpty);
    final v = await db.customSelect('PRAGMA user_version').get();
    expect(v.single.data.values.single, db.schemaVersion);
  });

  test('a version 8 database keeps its misbaha log as its own', () async {
    final dir = Directory.systemTemp.createTempSync('sync_migration_9');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/user.db');
    final fresh = UserDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.close();
    final raw = sqlite3.open(file.path)
      ..execute('DROP TABLE tasbih_day')
      ..execute(
        'CREATE TABLE tasbih_day (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'day TEXT NOT NULL, dhikr TEXT NOT NULL, count INTEGER NOT NULL '
        'DEFAULT 0, rounds INTEGER NOT NULL DEFAULT 0, updated_at INTEGER '
        'NOT NULL, UNIQUE (day, dhikr))',
      )
      ..execute(
        'INSERT INTO tasbih_day (day, dhikr, count, rounds, updated_at) '
        "VALUES ('2026-10-01', 'app:seen34', 33, 1, 1)",
      )
      ..execute(
        'INSERT INTO sync_journal (entity, record_key, hash, updated_at, '
        "device_id, deleted) VALUES ('tasbih_day', 'k', 'h', 1, 'd', 0), "
        "('khatma', 'k', 'h', 1, 'd', 0)",
      )
      ..execute('PRAGMA user_version = 8');
    raw.close();
    final db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final row = await db.select(db.tasbihDays).getSingle();
    expect((row.count, row.rounds, row.device), (33, 1, ''));
    final journal = await db.select(db.syncJournal).get();
    expect(journal.map((j) => j.entity), ['khatma']);
    await TasbihRepository(db).record('app:seen34', at: DateTime(2026, 10, 1));
    expect((await db.select(db.tasbihDays).getSingle()).count, 34);
  });
}
