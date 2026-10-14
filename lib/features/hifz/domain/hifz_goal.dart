import 'dart:convert';

import '../../khatma/domain/day.dart';
import '../../khatma/domain/interval_set.dart';
import '../../khatma/domain/khatmah.dart';
import '../../khatma/domain/planner.dart';
import '../../khatma/domain/quran_index.dart';
import '../../khatma/domain/recovery.dart';

/// The ready-made goals. Each is a plan on the khatma engine; its progress
/// is counted by recitation (mastery), never by marking by hand.
enum GoalTemplate {
  /// Juz ʿAmma in two months.
  amma,

  /// A page a day, from a surah on, with no end date.
  pageDaily,

  /// A hizb reviewed each week (a review goal).
  hizbWeekly,

  /// Fixing a surah: recite it all to mastery in two weeks (a review
  /// goal).
  fixSurah,
}

/// A goal, free of storage.
class HifzGoal {
  const HifzGoal({
    required this.uuid,
    required this.template,
    required this.rangeStart,
    required this.rangeEnd,
    required this.startDate,
    this.targetDate,
    this.planFrom,
    this.dailyWeight,
    this.unit = WirdUnit.page,
    this.status = KhatmahStatus.active,
    this.pauses = const [],
    this.recovery,
    this.reminderTime,
    this.review = false,
  });

  final String uuid;

  /// Null for an open goal.
  final GoalTemplate? template;
  final int rangeStart, rangeEnd;
  final Day startDate;
  final Day? targetDate;
  final Day? planFrom;
  final double? dailyWeight;
  final WirdUnit unit;
  final KhatmahStatus status;
  final List<PausePeriod> pauses;
  final RecoveryChoice? recovery;
  final int? reminderTime;
  final bool review;

  /// The goal as a khatma, for the planner, the recovery and the reminders.
  Khatmah get khatmah => Khatmah(
    uuid: uuid,
    title: template?.name ?? 'open',
    kind: KhatmahKind.custom,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    pacing: targetDate == null ? PacingMode.dailyAmount : PacingMode.endDate,
    dailyWeight: dailyWeight,
    startDate: startDate,
    targetDate: targetDate,
    planFrom: planFrom,
    unit: unit,
    status: status,
    pauses: pauses,
    recovery: recovery,
    reminderTime: reminderTime,
  );

  /// The verses that count for the goal: every mastered verse for a
  /// memorizing goal (one mastered before it began is done already); for a
  /// review goal, only those recited to mastery since it began.
  List<Credit> credits(Iterable<(int, DateTime)> mastered) {
    final byDay = <Day, (Set<int>, DateTime)>{};
    for (final (verse, at) in mastered) {
      if (verse < rangeStart || verse > rangeEnd) continue;
      final day = Day.of(at);
      if (review && day.isBefore(startDate)) continue;
      final e = byDay[day] ??= (<int>{}, at);
      e.$1.add(verse);
    }
    return [
      for (final MapEntry(key: day, value: (ids, at)) in byDay.entries)
        Credit(
          sessionUuid: 'recited-${day.key}',
          khatmaUuid: uuid,
          ranges: IntervalSet.of(ids),
          newWeight: 0,
          decidedBy: DecidedBy.auto,
          day: day,
          at: at,
        ),
    ];
  }

  static String pausesToJson(List<PausePeriod> p) => jsonEncode([
    for (final x in p) [x.from.key, x.to?.key],
  ]);

  static List<PausePeriod> pausesFromJson(String text) {
    try {
      return [
        for (final e in jsonDecode(text) as List)
          PausePeriod(
            Day.parse((e as List)[0] as String),
            e[1] == null ? null : Day.parse(e[1] as String),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// Where a goal stands today: its ledger, today's «احفظ» portion, the
/// recovery state and the share mastered.
class GoalStatus {
  GoalStatus._(this.goal, this.ledger, this.wird, this.recovery, this.share);

  factory GoalStatus.of(
    HifzGoal goal,
    Iterable<(int, DateTime)> mastered,
    QuranIndex index,
    Day today,
  ) {
    final k = goal.khatmah;
    final ledger = Ledger(k, goal.credits(mastered), index);
    final planner = Planner(index);
    final snap = Snapper(index, index.madina1441, quarters: true);
    final total = index.weightOf(goal.rangeStart, goal.rangeEnd);
    return GoalStatus._(
      goal,
      ledger,
      ledger.complete ? null : planner.wird(k, ledger, today, snap),
      Recovery(planner).state(k, ledger, today),
      total <= 0 ? 0 : (ledger.coveredWeight / total).clamp(0, 1),
    );
  }

  final HifzGoal goal;
  final Ledger ledger;

  /// Today's portion to memorize (or recite, for a review goal); null on a
  /// rest or paused day, or once complete.
  final Wird? wird;
  final RecoveryState recovery;

  /// Weight mastered over the goal's weight, 0..1.
  final double share;

  bool get complete => ledger.complete;
}

/// A template's plan from [today]: its verses, days and unit. [surah] is
/// the surah chosen for [GoalTemplate.pageDaily] (where to start) and
/// [GoalTemplate.fixSurah]; [hizb] the hizb for [GoalTemplate.hizbWeekly].
({int from, int to, int? days, double? daily, WirdUnit unit, bool review})
templatePlan(GoalTemplate t, QuranIndex index, {int surah = 1, int hizb = 60}) {
  switch (t) {
    case GoalTemplate.amma:
      final from = index.juzEnds[28] + 1;
      return (
        from: from,
        to: index.ayahCount,
        days: 60,
        daily: null,
        unit: WirdUnit.page,
        review: false,
      );
    case GoalTemplate.pageDaily:
      return (
        from: index.surahFirst(surah),
        to: index.ayahCount,
        days: null,
        daily: 1,
        unit: WirdUnit.page,
        review: false,
      );
    case GoalTemplate.hizbWeekly:
      final to = index.hizbEnds[hizb - 1];
      final from = hizb == 1 ? 1 : index.hizbEnds[hizb - 2] + 1;
      return (
        from: from,
        to: to,
        days: 7,
        daily: null,
        unit: WirdUnit.rub,
        review: true,
      );
    case GoalTemplate.fixSurah:
      final from = index.surahFirst(surah);
      return (
        from: from,
        to: from + index.ayahCountOf(surah) - 1,
        days: 14,
        daily: null,
        unit: WirdUnit.page,
        review: true,
      );
  }
}
