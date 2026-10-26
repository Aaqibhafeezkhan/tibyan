import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/khatma/domain/weekly_report.dart';
import 'package:tibyan/features/khatma/services/reminder_scheduler.dart';
import 'package:tibyan/features/khatma/services/weekly_reminder.dart';

void main() {
  const last = Day(2026, 10, 26);
  DateTime at(int daysBack, [int hour = 10]) =>
      last.add(-daysBack).start.add(Duration(hours: hour));

  test('a week with nothing recorded is a fresh start, never an error', () {
    final r = buildWeeklyReport(last: last);
    expect(r.days, hasLength(7));
    expect(r.first, const Day(2026, 10, 20));
    expect(r.isEmpty, isTrue);
    expect(r.activeDays, 0);
    expect(r.missedDays, 0); // the fresh start says it; no count
    expect(r.note, WeeklyNote.freshStart);
  });

  test('reading and listening add up inside the week only', () {
    final r = buildWeeklyReport(
      last: last,
      reading: [
        (at(0), at(0).add(const Duration(minutes: 20)), 5),
        (at(3), at(3).add(const Duration(minutes: 10)), 2),
        (at(7), at(7).add(const Duration(minutes: 30)), 9), // last week
      ],
      listening: [(at(1), 600)],
    );
    expect(r.pages, 7);
    expect(r.readingMinutes, 30);
    expect(r.listeningMinutes, 10);
    expect(r.activeDays, 3);
    expect(r.missedDays, 4);
    expect(r.note, WeeklyNote.someDays);
  });

  test('recitations count sessions and distinct verses; they make a day '
      'active', () {
    final r = buildWeeklyReport(
      last: last,
      recitations: [at(2), at(2, 20), at(9)],
      recitedVerses: [(at(2), 8), (at(2), 9), (at(2, 20), 8), (at(9), 1)],
    );
    expect(r.recitations, 2);
    expect(r.versesRecited, 2);
    expect(r.activeDays, 1);
    expect(r.isEmpty, isFalse);
  });

  test('tasbih counts by day key, inside the week', () {
    final r = buildWeeklyReport(
      last: last,
      tasbih: {'2026-10-26': 33, '2026-10-20': 100, '2026-10-19': 500},
    );
    expect(r.tasbih, 133);
    expect(r.activeDays, 2);
  });

  test('most days active reads as a steady week', () {
    final r = buildWeeklyReport(
      last: last,
      reading: [
        for (var i = 0; i < 5; i++)
          (at(i), at(i).add(const Duration(minutes: 5)), 1),
      ],
    );
    expect(r.note, WeeklyNote.mostDays);
    expect(r.missedDays, 2);
  });

  test('a full week has no missed days', () {
    final r = buildWeeklyReport(
      last: last,
      tasbih: {for (var i = 0; i < 7; i++) last.add(-i).key: 1},
    );
    expect(r.missedDays, 0);
  });

  test('khatma: the share read this week, from the daily weight', () {
    final week = {for (var i = 0; i < 7; i++) last.add(-i)};
    final r = buildWeeklyReport(
      last: last,
      khatmas: [
        (
          title: 'Ramadan',
          progress: 0.5, // 300 of 600
          coveredWeight: 300,
          weightOn: (d) => week.contains(d) ? 10 : 50,
        ),
        (title: 'New', progress: 0, coveredWeight: 0, weightOn: (d) => 0),
      ],
    );
    expect(r.khatmas.first.progress, 0.5);
    expect(r.khatmas.first.gained, closeTo(70 / 600, 1e-9));
    expect(r.khatmas.last.gained, 0);
    expect(r.isEmpty, isFalse);
  });

  test('reportWeek steps back whole weeks', () {
    final w = reportWeek(last, weeksBack: 1);
    expect(w.last, const Day(2026, 10, 19));
    expect(w.first, const Day(2026, 10, 13));
  });

  group('nextWeeklyTimes', () {
    // 2026-10-26 is a Monday.
    final monday = DateTime(2026, 10, 26, 12);

    test('later this week, then weekly', () {
      final t = nextWeeklyTimes(
        monday,
        weekday: DateTime.friday,
        minutes: 20 * 60,
        count: 2,
      );
      expect(t, [DateTime(2026, 10, 30, 20), DateTime(2026, 11, 6, 20)]);
    });

    test('today when the time is still ahead, next week when it passed', () {
      expect(
        nextWeeklyTimes(
          monday,
          weekday: DateTime.monday,
          minutes: 13 * 60,
        ).first,
        DateTime(2026, 10, 26, 13),
      );
      expect(
        nextWeeklyTimes(
          monday,
          weekday: DateTime.monday,
          minutes: 9 * 60,
        ).first,
        DateTime(2026, 11, 2, 9),
      );
    });
  });

  test('the reminder: four weeks ahead when on, none when off', () async {
    final scheduler = NoReminders();
    final now = DateTime(2026, 10, 26, 12);
    const on = AppSettings(styleId: 'simple', weeklyReminder: true);
    await syncWeeklyReminder(scheduler, on, now: now);
    expect(scheduler.once.keys, [
      for (var i = 0; i < weeklyRemindersAhead; i++) weeklyReminderIdBase + i,
    ]);
    expect(scheduler.once[weeklyReminderIdBase], DateTime(2026, 10, 30, 20));
    await syncWeeklyReminder(
      scheduler,
      const AppSettings(styleId: 'simple'),
      now: now,
    );
    expect(scheduler.once, isEmpty);
  });
}
