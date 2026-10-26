import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'habit_tables.dart';
import 'hifz_tables.dart';
import 'tasbih_tables.dart';

export 'habit_tables.dart';
export 'hifz_tables.dart';
export 'tasbih_tables.dart';

part 'user_database.g.dart';

/// Named bookmarks ("fawasil"). Each one moves to the last place read
/// with it and has its own colour.
@DataClassName('BookmarkSetRow')
class BookmarkSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// ARGB colour.
  IntColumn get color => integer()();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();
  IntColumn get page => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  /// One of [MarkKind] for the four fixed marks; null for the reader's
  /// own named fawasil.
  TextColumn get kind => text().nullable()();

  /// The same on every device, so a named fasil syncs as one record even
  /// when it moves or is renamed. Added in version 8; older rows got one
  /// in the upgrade. The four fixed marks sync by [kind] instead.
  TextColumn get uuid => text().nullable().clientDefault(newUuid)();
}

/// «المزامنة»: what this device knows of each synced record, so a change
/// (or a deletion) is noticed between two syncs and the newer write wins
/// across devices. [hash] is of the row as last seen here; a tombstone
/// ([deleted]) keeps the record's key after the row is gone.
@DataClassName('SyncJournalRow')
class SyncJournal extends Table {
  @override
  String get tableName => 'sync_journal';

  TextColumn get entity => text()();
  TextColumn get recordKey => text()();
  TextColumn get hash => text().nullable()();

  /// Milliseconds since the epoch of the record's last change.
  IntColumn get updatedAt => integer()();

  /// The device that made that change.
  TextColumn get deviceId => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {entity, recordKey};
}

/// The four fixed marks, set with one tap.
enum MarkKind {
  reading(0xFF2F6FD0),
  review(0xFFD0453B),
  hifz(0xFF2E9A53),
  tadabbur(0xFFC98A12);

  const MarkKind(this.color);

  /// ARGB colour.
  final int color;
}

/// The last reading position, saved automatically. One row.
@DataClassName('ReadingPositionRow')
class ReadingPositions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get edition => text()();
  TextColumn get view => text()();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();
  IntColumn get page => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    BookmarkSets,
    ReadingPositions,
    Khatmas,
    KhatmaLogs,
    ReadingSessions,
    ListeningSessions,
    Reflections,
    Outbox,
    SrsItems,
    Memorizations,
    KhatmaPauses,
    SessionAttributions,
    KhatmaCoverages,
    DailyStats,
    RecitationSessions,
    RecitationVerses,
    RecitationWords,
    HifzGoals,
    TasbihDhikrs,
    TasbihDays,
    SyncJournal,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.executor);

  UserDatabase.open() : super(driftDatabase(name: 'user'));

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(bookmarkSets, bookmarkSets.kind);
      }
      if (from < 3) {
        // Khatma, reading reports, tadabbur journal and the sync outbox.
        // Tables are created only if missing, so this step is safe to run
        // after or before other branches' steps.
        await _createHabitTables(m);
      }
      if (from < 4) {
        // Hifz: spaced review units and memorization strength. Also
        // created only if missing.
        await m.createTable(srsItems);
        await m.createTable(memorizations);
      }
      if (from < 5) await _toKhatmahV5(m);
      if (from < 6) {
        // Hifz progress: the recitation record and hifz goals. New tables
        // only; nothing existing is touched.
        await m.createTable(recitationSessions);
        await m.createTable(recitationVerses);
        await m.createTable(recitationWords);
        await m.createTable(hifzGoals);
      }
      if (from < 7) {
        // «المسبحة»: the reader's own adhkar and the daily log. New
        // tables only.
        await m.createTable(tasbihDhikrs);
        await m.createTable(tasbihDays);
      }
      if (from < 8) {
        // «المزامنة»: a stable id for the fawasil and the sync journal.
        // Guarded like v5's columns, so a database stamped older than it
        // is runs this step safely.
        final have = {
          for (final r in await customSelect(
            'PRAGMA table_info("bookmark_sets")',
          ).get())
            r.read<String>('name'),
        };
        if (!have.contains('uuid')) {
          await m.addColumn(bookmarkSets, bookmarkSets.uuid);
        }
        await customStatement(
          'UPDATE bookmark_sets SET uuid = lower(hex(randomblob(16))) '
          'WHERE uuid IS NULL',
        );
        await m.createTable(syncJournal);
      }
      if (from < 9) {
        // «المزامنة»: the misbaha's daily log keeps one row a device, so
        // counts from several devices add up. Existing rows are this
        // device's; their journal entries (keyed without a device) go.
        final cols = {
          for (final r in await customSelect(
            'PRAGMA table_info("tasbih_day")',
          ).get())
            r.read<String>('name'),
        };
        await m.alterTable(
          TableMigration(
            tasbihDays,
            newColumns: [if (!cols.contains('device')) tasbihDays.device],
          ),
        );
        await customStatement(
          "DELETE FROM sync_journal WHERE entity = 'tasbih_day'",
        );
      }
    },
  );

  /// Khatmah v1.1: khatmas over verse ranges with sessions and their
  /// attributions as the record. Old columns stay; the old log is carried
  /// over to sessions later, once the verse index is at hand
  /// (KhatmahStore.migrateLegacy), and is kept read-only.
  Future<void> _toKhatmahV5(Migrator m) async {
    // A v4 database made by an earlier step of this same upgrade (from < 3)
    // already has the new columns.
    final have = {
      for (final r in await customSelect('PRAGMA table_info("khatma")').get())
        r.read<String>('name'),
    };
    for (final c in [
      khatmas.kind,
      khatmas.rangeStart,
      khatmas.rangeEnd,
      khatmas.startAt,
      khatmas.pacingMode,
      khatmas.scheduleMode,
      khatmas.dailyWeight,
      khatmas.restWeekdays,
      khatmas.countingMode,
      khatmas.isPrimary,
      khatmas.status,
      khatmas.autoRestart,
      khatmas.presetId,
      khatmas.aheadChoice,
      khatmas.reminderKinds,
      khatmas.recovery,
    ]) {
      if (!have.contains(c.name)) await m.addColumn(khatmas, c);
    }
    final session = {
      for (final r in await customSelect(
        'PRAGMA table_info("reading_session")',
      ).get())
        r.read<String>('name'),
    };
    for (final c in [
      readingSessions.source,
      readingSessions.entryPoint,
      readingSessions.activeSeconds,
      readingSessions.ranges,
    ]) {
      if (!session.contains(c.name)) await m.addColumn(readingSessions, c);
    }
    await m.createTable(khatmaPauses);
    await m.createTable(sessionAttributions);
    await m.createTable(khatmaCoverages);
    await m.createTable(dailyStats);
    // What the old rows said by their dates: the status, how the plan was
    // made, and the khatma being read as the primary one.
    await customStatement(
      "UPDATE khatma SET status = CASE "
      "WHEN deleted_at IS NOT NULL THEN 'cancelled' "
      "WHEN completed_at IS NOT NULL THEN 'completed' ELSE 'active' END, "
      "pacing_mode = CASE WHEN daily_portion IS NULL THEN 'endDate' "
      "ELSE 'dailyAmount' END",
    );
    await customStatement(
      'UPDATE khatma SET is_primary = 1 WHERE id = (SELECT id FROM khatma '
      "WHERE status = 'active' ORDER BY created_at DESC, id DESC LIMIT 1)",
    );
  }

  Future<void> _createHabitTables(Migrator m) async {
    await m.createTable(khatmas);
    await m.createTable(khatmaLogs);
    await m.createTable(readingSessions);
    await m.createTable(listeningSessions);
    await m.createTable(reflections);
    await m.createTable(outbox);
  }

  /// Moves a fixed mark to a verse, creating it the first time.
  Future<void> setMark(
    MarkKind kind, {
    required String name,
    required int surah,
    required int ayah,
    required int page,
  }) async {
    final existing = await (select(
      bookmarkSets,
    )..where((t) => t.kind.equals(kind.name))).getSingleOrNull();
    if (existing != null) {
      await moveBookmarkSet(existing.id, surah: surah, ayah: ayah, page: page);
      return;
    }
    await into(bookmarkSets).insert(
      BookmarkSetsCompanion.insert(
        name: name,
        color: kind.color,
        surah: surah,
        ayah: ayah,
        page: page,
        sortOrder: Value(-10 + kind.index),
        kind: Value(kind.name),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Stream<ReadingPositionRow?> watchPosition() => (select(
    readingPositions,
  )..where((t) => t.id.equals(1))).watchSingleOrNull();

  Future<ReadingPositionRow?> position() => (select(
    readingPositions,
  )..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> savePosition({
    required String edition,
    required String view,
    required int surah,
    required int ayah,
    required int page,
  }) => into(readingPositions).insertOnConflictUpdate(
    ReadingPositionsCompanion.insert(
      id: const Value(1),
      edition: edition,
      view: view,
      surah: surah,
      ayah: ayah,
      page: page,
      updatedAt: DateTime.now(),
    ),
  );

  Stream<List<BookmarkSetRow>> watchBookmarkSets() =>
      (select(bookmarkSets)..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  Future<int> addBookmarkSet({
    required String name,
    required int color,
    required int surah,
    required int ayah,
    required int page,
  }) => into(bookmarkSets).insert(
    BookmarkSetsCompanion.insert(
      name: name,
      color: color,
      surah: surah,
      ayah: ayah,
      page: page,
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> moveBookmarkSet(
    int id, {
    required int surah,
    required int ayah,
    required int page,
  }) => (update(bookmarkSets)..where((t) => t.id.equals(id))).write(
    BookmarkSetsCompanion(
      surah: Value(surah),
      ayah: Value(ayah),
      page: Value(page),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Renames or recolours a fasil, where it is.
  Future<void> updateBookmarkSet(int id, {String? name, int? color}) =>
      (update(bookmarkSets)..where((t) => t.id.equals(id))).write(
        BookmarkSetsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          color: color == null ? const Value.absent() : Value(color),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteBookmarkSet(int id) =>
      (delete(bookmarkSets)..where((t) => t.id.equals(id))).go();
}
