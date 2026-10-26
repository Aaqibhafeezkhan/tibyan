import 'day.dart';
import 'reading_stats.dart';

/// One khatma over a week: where it stands now and the share read that
/// week (both 0 … 1 of the khatma).
typedef KhatmaWeek = ({String title, double progress, double gained});

/// What a khatma brings to the weekly report: its share read now, the
/// weight it has covered, and the weight read on each day.
typedef KhatmaWeekInput = ({
  String title,
  double progress,
  double coveredWeight,
  double Function(Day day) weightOn,
});

/// The calm line at the top of the weekly report. Nothing here counts
/// missed days or compares with another week (plan D9, decision 1).
enum WeeklyNote {
  /// Nothing recorded this week: an invitation, a new week to begin.
  freshStart,

  /// Some activity: a thank-you for what was done.
  someDays,

  /// Activity on most days of the week.
  mostDays,
}

/// The «تقرير أسبوعي»: seven days ending [last], from what the app already
/// records (reading and listening sessions, khatma progress, recitation
/// sessions, tasbih counts). All local.
class WeeklyReport {
  WeeklyReport({
    required this.reading,
    required this.khatmas,
    required this.recitations,
    required this.versesRecited,
    required this.tasbih,
    this.otherActive = const {},
  });

  /// Reading and listening per day, oldest first (seven days).
  final ReadingReport reading;

  /// Khatmas that are open, or that moved during the week.
  final List<KhatmaWeek> khatmas;

  /// Recitation sessions (tasmee by voice, recitation tests) begun in the
  /// week, and the distinct verses recited in them.
  final int recitations;
  final int versesRecited;

  /// Dhikr counted on the tasbih during the week.
  final int tasbih;

  List<DayActivity> get days => reading.days;
  Day get first => days.first.day;
  Day get last => days.last.day;

  int get pages => reading.pages;
  int get readingMinutes => reading.readingMinutes;
  int get listeningMinutes => reading.listeningMinutes;

  /// Days with reading or listening, or a recitation or tasbih on them.
  int get activeDays => [
    for (var i = 0; i < days.length; i++)
      if (days[i].active || otherActive.contains(days[i].day)) i,
  ].length;

  /// Days with a recitation session or tasbih counts.
  final Set<Day> otherActive;

  /// Whether anything at all was recorded in the week.
  bool get isEmpty =>
      activeDays == 0 &&
      recitations == 0 &&
      tasbih == 0 &&
      khatmas.every((k) => k.gained <= 0);

  WeeklyNote get note => isEmpty
      ? WeeklyNote.freshStart
      : activeDays >= 5
      ? WeeklyNote.mostDays
      : WeeklyNote.someDays;
}

/// The seven days ending [last] (inclusive); [weeksBack] moves that many
/// whole weeks earlier.
({Day first, Day last}) reportWeek(Day today, {int weeksBack = 0}) {
  final last = today.add(-7 * weeksBack);
  return (first: last.add(-6), last: last);
}

/// Builds the report for the seven days ending [last]. Sessions count on
/// the day they began; [tasbih] is the log by `yyyy-MM-dd` day key.
WeeklyReport buildWeeklyReport({
  required Day last,
  Iterable<(DateTime, DateTime, int)> reading = const [],
  Iterable<(DateTime, int)> listening = const [],
  Iterable<KhatmaWeekInput> khatmas = const [],
  Iterable<DateTime> recitations = const [],
  Iterable<(DateTime, int)> recitedVerses = const [],
  Map<String, int> tasbih = const {},
}) {
  final first = last.add(-6);
  bool inWeek(Day d) => !d.isBefore(first) && !d.isAfter(last);
  final week = [for (var i = 0; i < 7; i++) first.add(i)];

  final other = <Day>{};
  var sessions = 0;
  for (final t in recitations) {
    final d = Day.of(t);
    if (!inWeek(d)) continue;
    sessions++;
    other.add(d);
  }
  final verses = {
    for (final (t, v) in recitedVerses)
      if (inWeek(Day.of(t))) v,
  };
  var counted = 0;
  for (final d in week) {
    final n = tasbih[d.key] ?? 0;
    if (n <= 0) continue;
    counted += n;
    other.add(d);
  }

  final khatmaWeeks = <KhatmaWeek>[];
  for (final k in khatmas) {
    final weight = week.fold<double>(0, (s, d) => s + k.weightOn(d));
    final gained = k.progress <= 0 || k.coveredWeight <= 0
        ? 0.0
        : (weight * k.progress / k.coveredWeight).clamp(0.0, k.progress);
    khatmaWeeks.add((
      title: k.title,
      progress: k.progress.clamp(0.0, 1.0),
      gained: gained,
    ));
  }

  return WeeklyReport(
    reading: buildReport(
      today: last,
      count: 7,
      reading: reading,
      listening: listening,
    ),
    khatmas: khatmaWeeks,
    recitations: sessions,
    versesRecited: verses.length,
    tasbih: counted,
    otherActive: other,
  );
}

/// The next [count] times of the weekly reminder: on [weekday]
/// (`DateTime.monday` … `DateTime.sunday`) at [minutes] after midnight,
/// strictly after [now].
List<DateTime> nextWeeklyTimes(
  DateTime now, {
  required int weekday,
  required int minutes,
  int count = 4,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var ahead = (weekday - now.weekday) % 7;
  DateTime at(int days) => DateTime(
    today.year,
    today.month,
    today.day + days,
    minutes ~/ 60,
    minutes % 60,
  );
  if (!at(ahead).isAfter(now)) ahead += 7;
  return [for (var i = 0; i < count; i++) at(ahead + 7 * i)];
}
