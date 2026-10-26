import 'dart:ui' show Locale;

import '../../../core/settings/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/weekly_report.dart';
import 'reminder_scheduler.dart';

/// Notification ids of the weekly report reminder: a few weeks scheduled
/// ahead, and scheduled again whenever the app opens.
const weeklyReminderIdBase = 7600;
const weeklyRemindersAhead = 4;

/// Where a weekly reminder leads.
const weeklyReportLink = 'tibyan://weekly';
const weeklyReportLocation = '/khatma/reports/weekly';

/// Schedules (or, when turned off, cancels) the weekly report reminder.
/// Its text is fixed: the numbers are seen in the app, never in a
/// notification.
Future<void> syncWeeklyReminder(
  ReminderScheduler scheduler,
  AppSettings settings, {
  DateTime? now,
}) async {
  for (var i = 0; i < weeklyRemindersAhead; i++) {
    await scheduler.cancelOnce(weeklyReminderIdBase + i);
  }
  if (!settings.weeklyReminder) return;
  final l = lookupAppLocalizations(settings.locale ?? const Locale('ar'));
  final times = nextWeeklyTimes(
    now ?? DateTime.now(),
    weekday: settings.weeklyReminderWeekday,
    minutes: settings.weeklyReminderMinutes,
    count: weeklyRemindersAhead,
  );
  for (final (i, at) in times.indexed) {
    await scheduler.scheduleOnce(
      id: weeklyReminderIdBase + i,
      at: at,
      title: l.weeklyReminderTitle,
      body: l.weeklyReminderBody,
      payload: weeklyReportLink,
      channel: l.weeklyReminderChannel,
    );
  }
}
