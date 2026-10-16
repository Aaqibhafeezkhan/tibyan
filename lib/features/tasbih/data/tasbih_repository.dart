import 'package:drift/drift.dart';

import '../../../core/db/user_database.dart';
import '../domain/dhikr.dart';

/// The local day of [t] as `yyyy-MM-dd`: the log turns at local midnight.
String tasbihDayKey(DateTime t) {
  final d = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// How many days the log keeps, today included.
const tasbihLogDays = 30;

/// One day's totals: dhikr key -> (count, rounds).
typedef TasbihDayTotals = Map<String, ({int count, int rounds})>;

class TasbihRepository {
  TasbihRepository(this._db);

  final UserDatabase _db;

  // The reader's own adhkar.

  Stream<List<Dhikr>> watchMine() =>
      (_db.select(_db.tasbihDhikrs)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch()
          .map((rows) => [for (final r in rows) _dhikr(r)]);

  Future<List<Dhikr>> mine() => watchMine().first;

  static Dhikr _dhikr(TasbihDhikrRow r) => Dhikr(
    key: 'user:${r.uuid}',
    text: r.body,
    reference: r.reference,
    target: r.target,
    mine: true,
  );

  Future<Dhikr> add(String text, {String? reference, int? target}) async {
    final id = await _db
        .into(_db.tasbihDhikrs)
        .insert(
          TasbihDhikrsCompanion.insert(
            body: text.trim(),
            reference: Value(_blank(reference)),
            target: Value(target),
          ),
        );
    final row = await (_db.select(
      _db.tasbihDhikrs,
    )..where((t) => t.id.equals(id))).getSingle();
    return _dhikr(row);
  }

  Future<void> edit(
    String uuid, {
    required String text,
    String? reference,
    int? target,
  }) => (_db.update(_db.tasbihDhikrs)..where((t) => t.uuid.equals(uuid))).write(
    TasbihDhikrsCompanion(
      body: Value(text.trim()),
      reference: Value(_blank(reference)),
      target: Value(target),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// A soft delete, so a restore from an older backup does not bring it
  /// back as new.
  Future<void> remove(String uuid) =>
      (_db.update(_db.tasbihDhikrs)..where((t) => t.uuid.equals(uuid))).write(
        TasbihDhikrsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  static String? _blank(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();

  // The daily log.

  /// Adds [count] counts and [rounds] closed rounds to [dhikr]'s total on
  /// [at]'s day.
  Future<void> record(
    String dhikr, {
    int count = 1,
    int rounds = 0,
    DateTime? at,
  }) async {
    if (count <= 0 && rounds <= 0) return;
    final day = tasbihDayKey(at ?? DateTime.now());
    await _db.customStatement(
      'INSERT INTO tasbih_day (day, dhikr, "count", rounds, updated_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(day, dhikr) DO UPDATE SET '
      '"count" = "count" + excluded."count", rounds = rounds + excluded.rounds, '
      'updated_at = excluded.updated_at',
      [
        day,
        dhikr,
        count,
        rounds,
        (DateTime.now().millisecondsSinceEpoch / 1000).floor(),
      ],
    );
    _db.notifyUpdates({TableUpdate.onTable(_db.tasbihDays)});
  }

  /// [dhikr]'s count on [at]'s day.
  Future<int> dayCount(String dhikr, {DateTime? at}) async {
    final day = tasbihDayKey(at ?? DateTime.now());
    final row =
        await (_db.select(_db.tasbihDays)
              ..where((t) => t.day.equals(day) & t.dhikr.equals(dhikr)))
            .getSingleOrNull();
    return row?.count ?? 0;
  }

  /// Drops the days older than the log keeps.
  Future<int> prune({DateTime? now}) {
    final first = tasbihDayKey(
      (now ?? DateTime.now()).subtract(const Duration(days: tasbihLogDays - 1)),
    );
    return (_db.delete(
      _db.tasbihDays,
    )..where((t) => t.day.isSmallerThanValue(first))).go();
  }

  /// The log, newest day first: day -> totals.
  Stream<Map<String, TasbihDayTotals>> watchLog() =>
      (_db.select(_db.tasbihDays)..orderBy([
            (t) => OrderingTerm.desc(t.day),
            (t) => OrderingTerm.desc(t.count),
          ]))
          .watch()
          .map((rows) {
            final out = <String, TasbihDayTotals>{};
            for (final r in rows) {
              (out[r.day] ??= {})[r.dhikr] = (count: r.count, rounds: r.rounds);
            }
            return out;
          });

  /// Today's total of every dhikr together.
  Stream<int> watchToday({DateTime Function()? now}) => watchLog().map((log) {
    final today = log[tasbihDayKey((now ?? DateTime.now)())];
    if (today == null) return 0;
    return today.values.fold(0, (a, e) => a + e.count);
  });
}
