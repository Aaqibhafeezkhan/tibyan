import '../../../core/db/user_database.dart';
import '../../khatma/domain/quran_index.dart';
import '../domain/fsrs.dart';
import '../domain/recitation_record.dart';
import '../domain/strength.dart';
import 'hifz_store.dart';
import 'recitation_store.dart';

/// What a saved session changed in mastery, for «حُفظت النتيجة».
class MasteryChange {
  const MasteryChange({
    required this.saved,
    required this.mastered,
    required this.newlyMastered,
    required this.needReview,
  });

  /// The session went into the record.
  final bool saved;

  /// Verses of the session at the threshold or above.
  final int mastered;

  /// Of those, verses not mastered before this session.
  final int newlyMastered;

  /// Verses below the threshold: they come up for review early.
  final int needReview;

  static const none = MasteryChange(
    saved: false,
    mastered: 0,
    newlyMastered: 0,
    needReview: 0,
  );
}

/// Saves a session in the record, then lets it update memorization: each
/// recited verse's strength, and the schedule of every review unit it
/// touches (FSRS). Verses with nothing judged are left as they were.
/// [applyMemory] false only records it: a unit's test grades its unit and
/// verses itself (gradeUnit, saveVerseResults).
Future<MasteryChange> recordRecitation(
  UserDatabase db,
  QuranIndex index,
  RecitationRecord r, {
  bool applyMemory = true,
}) async {
  if (r.verses.isEmpty) return MasteryChange.none;
  final before = await db.watchVerseLatest().first;
  await db.saveRecitation(r);

  String ref(int id) {
    final f = index.facts(id);
    return verseRef(f.surah, f.ayah);
  }

  final judged = [
    for (final v in r.verses)
      if (v.accuracy != null) v,
  ];
  if (!applyMemory) return _change(judged, before);
  final strengths = await db.verseStrengths(judged.map((v) => ref(v.verse)));
  await db.setVerseStrengths({
    for (final v in judged)
      ref(v.verse): strengthAfterRecitation(
        Strength.of(strengths[ref(v.verse)]),
        v.accuracy,
      ).level,
  });

  // Review units the session touched.
  final byVerse = {for (final v in judged) v.verse: v.accuracy};
  for (final item in await db.watchSrsItems().first) {
    final a = parseVerseRef(item.fromRef), b = parseVerseRef(item.toRef);
    final from = index.idOf(a.$1, a.$2), to = index.idOf(b.$1, b.$2);
    final inUnit = [
      for (final e in byVerse.entries)
        if (e.key >= from && e.key <= to) e.value,
    ];
    final grade = gradeFromAccuracies(inUnit);
    if (grade == null) continue;
    final review = const Fsrs().review(
      state: MemoryState(
        stability: item.stability,
        difficulty: item.difficulty,
      ),
      lastReview: item.lastReviewAt,
      grade: grade,
      now: r.endedAt,
    );
    await db.saveSrsReview(
      unit: item.unit,
      fromRef: item.fromRef,
      toRef: item.toRef,
      stability: review.state.stability,
      difficulty: review.state.difficulty,
      dueAt: review.due,
      lapse: grade == Grade.again,
      now: r.endedAt,
    );
  }

  return _change(judged, before);
}

MasteryChange _change(
  List<VerseResultRecord> judged,
  Map<int, VerseLatest> before,
) {
  var mastered = 0, fresh = 0, low = 0;
  for (final v in judged) {
    if (v.mastered) {
      mastered++;
      if (!isMastered(before[v.verse]?.accuracy)) fresh++;
    } else {
      low++;
    }
  }
  return MasteryChange(
    saved: true,
    mastered: mastered,
    newlyMastered: fresh,
    needReview: low,
  );
}
