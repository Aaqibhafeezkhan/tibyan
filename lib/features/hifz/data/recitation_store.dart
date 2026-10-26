import 'package:drift/drift.dart';

import '../../../core/db/user_database.dart';
import '../domain/recitation_record.dart';

/// A word read wrong or skipped more than once: where it is, how often,
/// and when last.
typedef HardWord = ({int verse, int word, int count, DateTime last});

/// A verse's latest recitation.
typedef VerseLatest = ({double? accuracy, DateTime at});

/// Reads and writes of the recitation record in user.db.
extension RecitationStore on UserDatabase {
  /// Saves a session with its verses and slips, in one transaction; returns
  /// its uuid. Nothing is saved for a session with no verse.
  Future<String?> saveRecitation(RecitationRecord r) async {
    if (r.verses.isEmpty) return null;
    return transaction(() async {
      final uuid = newUuid();
      await into(recitationSessions).insert(
        RecitationSessionsCompanion.insert(
          uuid: Value(uuid),
          kind: r.kind.name,
          fromVerse: r.fromVerse,
          toVerse: r.toVerse,
          startedAt: r.startedAt,
          endedAt: r.endedAt,
          accuracy: Value(r.accuracy),
          sensitivity: Value(r.sensitivity),
          updatedAt: Value(r.endedAt),
        ),
      );
      for (final v in r.verses) {
        await into(recitationVerses).insert(
          RecitationVersesCompanion.insert(
            session: uuid,
            verse: v.verse,
            accuracy: Value(v.accuracy),
            words: Value(v.words),
            wrong: Value(v.wrong),
            skipped: Value(v.skipped),
            corrected: Value(v.corrected),
            doubtful: Value(v.doubtful),
            at: r.endedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final s in r.slips) {
        await into(recitationWords).insert(
          RecitationWordsCompanion.insert(
            session: uuid,
            verse: s.verse,
            word: s.word,
            kind: s.skipped ? 'skipped' : 'wrong',
            at: r.endedAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      return uuid;
    });
  }

  /// Sessions begun since [since] (not deleted): when, and their uuid; for
  /// the weekly report.
  Stream<List<(DateTime, String)>> watchRecitationStartsSince(DateTime since) =>
      (select(recitationSessions)..where(
            (t) =>
                t.startedAt.isBiggerOrEqualValue(since) & t.deletedAt.isNull(),
          ))
          .watch()
          .map((rows) => [for (final r in rows) (r.startedAt, r.uuid)]);

  /// Verses recited since [since]: when, `ayah.id` and the session's uuid.
  Stream<List<(DateTime, int, String)>> watchRecitedVersesSince(
    DateTime since,
  ) =>
      (select(recitationVerses)..where((t) => t.at.isBiggerOrEqualValue(since)))
          .watch()
          .map((rows) => [for (final r in rows) (r.at, r.verse, r.session)]);

  /// Sessions, newest first (not deleted).
  Stream<List<RecitationSessionRow>> watchRecitations() =>
      (select(recitationSessions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.endedAt)]))
          .watch();

  Future<RecitationSessionRow?> recitation(String uuid) => (select(
    recitationSessions,
  )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  Future<List<RecitationVerseRow>> versesOfRecitation(String uuid) =>
      (select(recitationVerses)
            ..where((t) => t.session.equals(uuid))
            ..orderBy([(t) => OrderingTerm.asc(t.verse)]))
          .get();

  Future<List<RecitationWordRow>> slipsOfRecitation(String uuid) =>
      (select(recitationWords)
            ..where((t) => t.session.equals(uuid))
            ..orderBy([
              (t) => OrderingTerm.asc(t.verse),
              (t) => OrderingTerm.asc(t.word),
            ]))
          .get();

  /// Each recited verse's latest result, by `ayah.id`.
  Stream<Map<int, VerseLatest>> watchVerseLatest() =>
      customSelect(
        'SELECT v.verse AS verse, v.accuracy AS accuracy, v."at" AS at '
        'FROM recitation_verse v JOIN recitation_session s ON s.uuid = v.session '
        'WHERE s.deleted_at IS NULL AND v.accuracy IS NOT NULL '
        'ORDER BY v."at", v.id',
        readsFrom: {recitationVerses, recitationSessions},
      ).watch().map((rows) {
        final out = <int, VerseLatest>{};
        for (final r in rows) {
          out[r.read<int>('verse')] = (
            accuracy: r.read<double?>('accuracy'),
            at: r.read<DateTime>('at'),
          );
        }
        return out;
      });

  /// Every recitation of a verse at the threshold or above, oldest first:
  /// (`ayah.id`, when), for goals counted by mastery.
  Stream<List<(int, DateTime)>> watchMasteredEvents() =>
      customSelect(
        'SELECT v.verse AS verse, v."at" AS at FROM recitation_verse v '
        'JOIN recitation_session s ON s.uuid = v.session '
        'WHERE s.deleted_at IS NULL AND v.accuracy >= ? ORDER BY v."at"',
        variables: [Variable.withReal(masteryThreshold - 1e-9)],
        readsFrom: {recitationVerses, recitationSessions},
      ).watch().map(
        (rows) => [
          for (final r in rows) (r.read<int>('verse'), r.read<DateTime>('at')),
        ],
      );

  /// Words slipped on more than once, most often first, then latest.
  Stream<List<HardWord>> watchHardWords({int minCount = 2}) =>
      customSelect(
        'SELECT w.verse AS verse, w.word AS word, COUNT(*) AS n, '
        'MAX(w."at") AS last FROM recitation_word w '
        'JOIN recitation_session s ON s.uuid = w.session '
        'WHERE s.deleted_at IS NULL GROUP BY w.verse, w.word '
        'HAVING COUNT(*) >= ? ORDER BY n DESC, last DESC',
        variables: [Variable.withInt(minCount)],
        readsFrom: {recitationWords, recitationSessions},
      ).watch().map(
        (rows) => [
          for (final r in rows)
            (
              verse: r.read<int>('verse'),
              word: r.read<int>('word'),
              count: r.read<int>('n'),
              last: r.read<DateTime>('last'),
            ),
        ],
      );

  /// Removes a session from the record (kept as deleted).
  Future<void> deleteRecitation(String uuid) {
    final now = DateTime.now();
    return (update(
      recitationSessions,
    )..where((t) => t.uuid.equals(uuid))).write(
      RecitationSessionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // -- goals ---------------------------------------------------------------

  Stream<List<HifzGoalRow>> watchHifzGoals() =>
      (select(hifzGoals)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.id)]))
          .watch();

  Future<int> addHifzGoal(HifzGoalsCompanion goal) =>
      into(hifzGoals).insert(goal);

  Future<void> updateHifzGoal(int id, HifzGoalsCompanion change) =>
      (update(hifzGoals)..where((t) => t.id.equals(id))).write(
        change.copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<void> deleteHifzGoal(int id) => updateHifzGoal(
    id,
    HifzGoalsCompanion(
      deletedAt: Value(DateTime.now()),
      status: const Value('cancelled'),
    ),
  );
}
