import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/backup/backup.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/features/hifz/data/hifz_store.dart';
import 'package:tibyan/features/hifz/data/recitation_service.dart';
import 'package:tibyan/features/hifz/data/recitation_store.dart';
import 'package:tibyan/features/hifz/domain/fsrs.dart';
import 'package:tibyan/features/hifz/domain/hifz_goal.dart';
import 'package:tibyan/features/hifz/domain/hifz_progress.dart';
import 'package:tibyan/features/hifz/domain/recitation_record.dart';
import 'package:tibyan/features/hifz/domain/strength.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/khatmah.dart';
import 'package:tibyan/features/khatma/domain/quran_index.dart';

import '../khatma/support.dart';

RecitationRecord _record(
  Map<int, double?> verses, {
  List<WordSlip> slips = const [],
  DateTime? at,
  RecitationKind kind = RecitationKind.voice,
}) {
  final end = at ?? DateTime(2026, 10, 13, 9);
  return RecitationRecord(
    kind: kind,
    startedAt: end.subtract(const Duration(minutes: 5)),
    endedAt: end,
    sensitivity: 'medium',
    verses: [
      for (final e in verses.entries)
        VerseResultRecord(verse: e.key, accuracy: e.value, words: 10),
    ],
    slips: slips,
  );
}

void main() {
  late QuranIndex index;
  setUpAll(() async => index = await realIndex());

  test('schema 6 adds the record and goal tables and keeps v5 rows', () async {
    final dir = Directory.systemTemp.createTempSync('userdb');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/user.sqlite');
    // A v5 database: the current schema without the v6 tables, with rows.
    final v6 = UserDatabase(NativeDatabase(file));
    await v6.savePosition(
      edition: 'madina1441',
      view: 'page',
      surah: 2,
      ayah: 255,
      page: 42,
    );
    await v6.setVerseStrengths({'67:1': 3});
    await v6.close();
    final v5 = UserDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          if (raw.select('PRAGMA user_version').first.values.first == 7) {
            for (final t in [
              'recitation_session',
              'recitation_verse',
              'recitation_word',
              'hifz_goal',
            ]) {
              raw.execute('DROP TABLE $t');
            }
            raw.execute('PRAGMA user_version = 5');
          }
        },
      ),
    );
    addTearDown(v5.close);
    expect((await v5.position())!.page, 42);
    expect(await v5.watchVerseStrengths().first, {'67:1': 3});
    expect(await v5.watchRecitations().first, isEmpty);
    expect(await v5.watchHifzGoals().first, isEmpty);
    final v = await v5.customSelect('PRAGMA user_version').getSingle();
    expect(v.data.values.single, 7);
  });

  group('the record', () {
    late UserDatabase db;
    setUp(() => db = UserDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('90% or more masters a verse; less weakens it', () async {
      final mulk1 = index.idOf(67, 1), mulk2 = index.idOf(67, 2);
      await db.setVerseStrengths({'67:1': 2, '67:2': 3});
      final c = await recordRecitation(
        db,
        index,
        _record({mulk1: 0.9, mulk2: 0.89}),
      );
      expect(c.saved, isTrue);
      expect(c.newlyMastered, 1);
      expect(c.needReview, 1);
      final s = await db.verseStrengths(['67:1', '67:2']);
      expect(s['67:1'], Strength.good.level);
      expect(s['67:2'], Strength.weak.level);
      final latest = await db.watchVerseLatest().first;
      expect(isMastered(latest[mulk1]!.accuracy), isTrue);
      expect(isMastered(latest[mulk2]!.accuracy), isFalse);
      // Mastered again: not new any more.
      final again = await recordRecitation(db, index, _record({mulk1: 1}));
      expect(again.newlyMastered, 0);
      expect(again.mastered, 1);
    });

    test(
      'a verse with nothing judged (all unsure) keeps its strength',
      () async {
        await db.setVerseStrengths({'1:1': 3});
        await recordRecitation(db, index, _record({1: null}));
        expect((await db.verseStrengths(['1:1']))['1:1'], 3);
        expect(await db.watchRecitations().first, hasLength(1));
      },
    );

    test('the session accuracy leaves unsure words out', () {
      final r = RecitationRecord(
        kind: RecitationKind.voice,
        startedAt: DateTime(2026),
        endedAt: DateTime(2026),
        verses: const [
          VerseResultRecord(verse: 1, accuracy: 1, words: 4, doubtful: 2),
          VerseResultRecord(verse: 2, accuracy: 0.5, words: 2),
        ],
      );
      // (1 × 2 + 0.5 × 2) / 4
      expect(r.accuracy, closeTo(0.75, 1e-9));
    });

    test(
      'a review unit moves later when all its verses are mastered',
      () async {
        final now = DateTime(2026, 10, 13, 9);
        await db.saveSrsReview(
          unit: 'surah',
          fromRef: '112:1',
          toRef: '112:4',
          stability: 5,
          difficulty: 5,
          dueAt: now,
          lapse: false,
          now: now.subtract(const Duration(days: 5)),
        );
        final ids = [for (var a = 1; a <= 4; a++) index.idOf(112, a)];
        await recordRecitation(db, index, _record({for (final i in ids) i: 1}));
        var item = (await db.srsItem('surah', '112:1', '112:4'))!;
        expect(item.dueAt.isAfter(now.add(const Duration(days: 5))), isTrue);
        expect(item.reps, 2);
        // A weak recitation brings it back soon.
        await recordRecitation(
          db,
          index,
          _record({
            for (final i in ids) i: 0.4,
          }, at: now.add(const Duration(hours: 1))),
        );
        item = (await db.srsItem('surah', '112:1', '112:4'))!;
        expect(item.lapses, 1);
        expect(item.dueAt.difference(now).inDays, lessThan(3));
      },
    );

    test('grades from accuracies', () {
      expect(gradeFromAccuracies([0.95, 1]), Grade.good);
      expect(gradeFromAccuracies([0.95, 0.7]), Grade.hard);
      expect(gradeFromAccuracies([0.3, 0.5]), Grade.again);
      expect(gradeFromAccuracies([null]), isNull);
    });

    test('hard words: slipped on more than once, most often first', () async {
      await db.saveRecitation(
        _record({10: 0.5}, slips: [(verse: 10, word: 3, skipped: false)]),
      );
      expect(await db.watchHardWords().first, isEmpty);
      await db.saveRecitation(
        _record(
          {10: 0.5, 11: 0.8},
          slips: [
            (verse: 10, word: 3, skipped: true),
            (verse: 11, word: 1, skipped: false),
          ],
          at: DateTime(2026, 10, 14),
        ),
      );
      await db.saveRecitation(
        _record(
          {11: 0.8},
          slips: [(verse: 11, word: 1, skipped: false)],
          at: DateTime(2026, 10, 15),
        ),
      );
      await db.saveRecitation(
        _record(
          {10: 0.8},
          slips: [(verse: 10, word: 3, skipped: false)],
          at: DateTime(2026, 10, 12),
        ),
      );
      final hard = await db.watchHardWords().first;
      expect(hard.map((h) => (h.verse, h.word, h.count)), [
        (10, 3, 3),
        (11, 1, 2),
      ]);
      // Only places are stored: no text column at all.
      final cols = await db
          .customSelect('PRAGMA table_info("recitation_word")')
          .get();
      expect(cols.map((c) => c.read<String>('name')), isNot(contains('text')));
    });

    test('a deleted session leaves the record', () async {
      final uuid = (await db.saveRecitation(_record({1: 1})))!;
      await db.deleteRecitation(uuid);
      expect(await db.watchRecitations().first, isEmpty);
      expect(await db.watchVerseLatest().first, isEmpty);
    });

    test('backup and restore carry the record and goals', () async {
      final other = UserDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await db.saveRecitation(
        _record({5: 0.95, 6: 0.5}, slips: [(verse: 6, word: 2, skipped: true)]),
      );
      await db.addHifzGoal(
        HifzGoalsCompanion.insert(
          template: const Value('amma'),
          rangeStart: 5673,
          rangeEnd: 6236,
          startDate: '2026-10-13',
          targetDate: const Value('2026-12-12'),
        ),
      );
      final text = await Backup(db).export();
      await Backup(other).import(text);
      expect(await other.watchRecitations().first, hasLength(1));
      final s = (await other.watchRecitations().first).single;
      expect(await other.versesOfRecitation(s.uuid), hasLength(2));
      expect(await other.slipsOfRecitation(s.uuid), hasLength(1));
      expect((await other.watchHifzGoals().first).single.template, 'amma');
      // Twice adds nothing.
      final again = await Backup(other).import(text);
      expect(again.added, 0);
    });
  });

  group('goals on the khatma engine', () {
    final start = const Day(2026, 10, 1);
    HifzGoal amma({List<PausePeriod> pauses = const []}) {
      final p = templatePlan(GoalTemplate.amma, index);
      return HifzGoal(
        uuid: 'g',
        template: GoalTemplate.amma,
        rangeStart: p.from,
        rangeEnd: p.to,
        startDate: start,
        targetDate: start.add(p.days! - 1),
        unit: p.unit,
        pauses: pauses,
      );
    }

    test('ʿAmma: the range is juz 30, and today has a portion', () {
      final g = amma();
      expect(index.juzOf(g.rangeStart), 30);
      expect(index.juzOf(g.rangeStart - 1), 29);
      expect(g.rangeEnd, 6236);
      final s = GoalStatus.of(g, const [], index, start);
      expect(s.wird, isNotNull);
      expect(s.share, 0);
      // About 23 pages over 60 days: under a page a day.
      expect(s.recovery.nominal, lessThan(1));
    });

    test('progress counts mastered verses, not marks', () {
      final g = amma();
      final mastered = [
        for (var id = g.rangeStart; id < g.rangeStart + 40; id++)
          (id, DateTime(2026, 10, 2, 8)),
        (1, DateTime(2026, 10, 2)), // outside the goal
      ];
      final s = GoalStatus.of(g, mastered, index, const Day(2026, 10, 3));
      expect(s.share, greaterThan(0));
      expect(
        s.ledger.covered.containsRange(g.rangeStart, g.rangeStart + 39),
        isTrue,
      );
      // Behind after a week of nothing: the recovery suggests catching up.
      final later = GoalStatus.of(g, const [], index, const Day(2026, 10, 15));
      expect(later.recovery.deficit, greaterThan(0));
    });

    test('a paused day has no portion', () {
      final g = amma(pauses: [const PausePeriod(Day(2026, 10, 5))]);
      final s = GoalStatus.of(g, const [], index, const Day(2026, 10, 6));
      expect(s.wird, isNull);
    });

    test('a review goal counts only recitations since it began', () {
      final p = templatePlan(GoalTemplate.fixSurah, index, surah: 112);
      final g = HifzGoal(
        uuid: 'r',
        template: GoalTemplate.fixSurah,
        rangeStart: p.from,
        rangeEnd: p.to,
        startDate: start,
        targetDate: start.add(13),
        review: true,
      );
      final before = [
        for (var id = p.from; id <= p.to; id++) (id, DateTime(2026, 9, 1)),
      ];
      expect(GoalStatus.of(g, before, index, start).share, 0);
      final after = [
        for (var id = p.from; id <= p.to; id++) (id, DateTime(2026, 10, 2)),
      ];
      expect(
        GoalStatus.of(g, after, index, const Day(2026, 10, 3)).complete,
        isTrue,
      );
    });
  });

  test('progress: memorized, mastered, needs review and unrecited', () {
    final p = HifzProgress.of(
      index,
      {'1:1': 3, '1:2': 3, '1:3': 1},
      {
        index.idOf(1, 1): (accuracy: 0.95, at: DateTime(2026, 10, 1)),
        index.idOf(1, 4): (accuracy: 0.6, at: DateTime(2026, 10, 2)),
      },
      [0.95, 0.6],
    );
    expect(p.overall.memorized, 4);
    expect(p.overall.mastered, 1);
    expect(p.overall.needsReview, 2); // 1:3 weak, 1:4 below 90%
    expect(p.unrecited, 1); // 1:2
    expect(p.surahs.first.lastRecited, DateTime(2026, 10, 2));
    expect(p.accuracy30, closeTo(0.775, 1e-9));
    expect(p.juzMemorized, 0);
  });
}
