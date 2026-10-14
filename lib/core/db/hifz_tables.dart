import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'habit_tables.dart';

/// A UUID that is the same on every device for the same [key] (SHA-1 name
/// based, as RFC 4122 version 5 lays it out), so a hifz row made on two
/// devices for the same unit or verse is one row when synced.
String stableUuid(String key) {
  final b = sha1.convert(utf8.encode('tibyan:$key')).bytes.sublist(0, 16);
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// A unit in spaced review (lib/features/hifz/domain/fsrs.dart): a page,
/// a hizb quarter or a surah, kept as its verse range so it is the same in
/// every edition. Its uuid is [stableUuid] of `srs:unit:from:to`.
@DataClassName('SrsItemRow')
class SrsItems extends Table with SyncColumns {
  @override
  String get tableName => 'srs_item';

  IntColumn get id => integer().autoIncrement()();

  /// `page`, `quarter` or `surah`.
  TextColumn get unit => text()();

  /// First and last verse, `surah:ayah`.
  TextColumn get fromRef => text()();
  TextColumn get toRef => text()();

  /// FSRS memory state: days to 90% recall, and difficulty 1..10.
  RealColumn get stability => real()();
  RealColumn get difficulty => real()();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewAt => dateTime().nullable()();
}

/// How firmly each verse is memorized, for the hifz map: [strength] 1 weak
/// to 4 strong (lib/features/hifz/domain/strength.dart). [unit] is `ayah`
/// and [ref] `surah:ayah`; the uuid is [stableUuid] of `memo:unit:ref`.
@DataClassName('MemorizationRow')
class Memorizations extends Table with SyncColumns {
  @override
  String get tableName => 'memorization';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get unit => text()();
  TextColumn get ref => text()();
  IntColumn get strength => integer()();
}

/// A recitation session (سجل التسميع): one tasmee by voice, a recitation
/// test on the page (by touch), and the like. Results only: no audio and no
/// text is ever stored. Added in schema 6.
@DataClassName('RecitationSessionRow')
class RecitationSessions extends Table with SyncColumns {
  @override
  String get tableName => 'recitation_session';

  IntColumn get id => integer().autoIncrement()();

  /// `voice`, `touch` or `test` ([RecitationKind]).
  TextColumn get kind => text()();

  /// First and last verse of the range recited, `ayah.id`.
  IntColumn get fromVerse => integer()();
  IntColumn get toVerse => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();

  /// Correct words over the words judged, 0..1; null when none was judged.
  RealColumn get accuracy => real().nullable()();

  /// The matching strictness of a voice session (`MatchStrictness.name`).
  TextColumn get sensitivity => text().nullable()();
}

/// One verse of a recitation session.
@DataClassName('RecitationVerseRow')
class RecitationVerses extends Table {
  @override
  String get tableName => 'recitation_verse';

  IntColumn get id => integer().autoIncrement()();

  /// The session's uuid.
  TextColumn get session => text()();

  /// `ayah.id`.
  IntColumn get verse => integer()();
  RealColumn get accuracy => real().nullable()();
  IntColumn get words => integer().withDefault(const Constant(0))();
  IntColumn get wrong => integer().withDefault(const Constant(0))();
  IntColumn get skipped => integer().withDefault(const Constant(0))();
  IntColumn get corrected => integer().withDefault(const Constant(0))();
  IntColumn get doubtful => integer().withDefault(const Constant(0))();

  /// When it was recited (the session's end), for the latest result.
  DateTimeColumn get at => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {session, verse},
  ];
}

/// A word read wrong or skipped in a session, by its place only: the verse
/// (`ayah.id`) and the word's number in it (as in `word_box.word`). Its
/// text is always read from content.db.
@DataClassName('RecitationWordRow')
class RecitationWords extends Table {
  @override
  String get tableName => 'recitation_word';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get session => text()();
  IntColumn get verse => integer()();
  IntColumn get word => integer()();

  /// `wrong` or `skipped`.
  TextColumn get kind => text()();
  DateTimeColumn get at => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {session, verse, word},
  ];
}

/// A hifz goal (أهداف الحفظ): verses to master by a day, on the khatma
/// engine (lib/features/hifz/domain/hifz_goal.dart). Added in schema 6.
@DataClassName('HifzGoalRow')
class HifzGoals extends Table with SyncColumns {
  @override
  String get tableName => 'hifz_goal';

  IntColumn get id => integer().autoIncrement()();

  /// A template's id ([GoalTemplate.name]), or null for an open goal.
  TextColumn get template => text().nullable()();

  /// Verses, `ayah.id`, both ends included.
  IntColumn get rangeStart => integer()();
  IntColumn get rangeEnd => integer()();

  /// `yyyy-MM-dd`; [targetDate] null for an open-ended goal.
  TextColumn get startDate => text()();
  TextColumn get targetDate => text().nullable()();

  /// The day the pace is counted from after a catch-up; null: [startDate].
  TextColumn get planFrom => text().nullable()();

  /// Madina pages a day, when set by amount.
  RealColumn get dailyWeight => real().nullable()();

  /// `WirdUnit.name`: where a day's portion ends.
  TextColumn get unit => text().withDefault(const Constant('page'))();

  /// `active`, `paused`, `completed` or `cancelled`.
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Pauses as JSON `[["2026-10-01","2026-10-04"], ["2026-10-09", null]]`.
  TextColumn get pauses => text().withDefault(const Constant('[]'))();

  /// A chosen catch-up ([RecoveryChoice.toJson]).
  TextColumn get recovery => text().nullable()();

  /// Daily reminder, minutes after midnight; null for none.
  IntColumn get reminderTime => integer().nullable()();

  /// A review goal (a hizb a week, fixing a surah): only recitations made
  /// since it began count. A memorizing goal counts every mastered verse.
  BoolColumn get review => boolean().withDefault(const Constant(false))();
}
