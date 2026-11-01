import 'dart:ui' show Locale;

import '../../../core/settings/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/navigation.dart' show verseLink;
import '../domain/weekly_report.dart' show nextWeeklyTimes;
import 'reminder_scheduler.dart';

/// Notification ids of the Friday Surah Al-Kahf reminder: a few Fridays
/// scheduled ahead, and scheduled again whenever the app opens.
const kahfReminderIdBase = 7700;
const kahfRemindersAhead = 4;

/// Friday, 09:00 local time.
const kahfReminderMinutes = 9 * 60;

/// A tap opens the first verse of Surah Al-Kahf (18:1) through the verse
/// link, which finds its page in the edition being read (1441, 1405 or a
/// riwaya's) from the edition's own page data.
final kahfReminderLink = verseLink(18, 1).toString();

/// Schedules (or, when turned off, cancels) the Friday reminder. Its text is
/// fixed and neutral: the surah's name only. On by default, but scheduled
/// only once notifying is already allowed: it never asks for the permission
/// itself (the scheduler's `onGranted` schedules it when another reminder,
/// or this switch, is granted).
Future<void> syncKahfReminder(
  ReminderScheduler scheduler,
  AppSettings settings, {
  DateTime? now,
}) async {
  for (var i = 0; i < kahfRemindersAhead; i++) {
    await scheduler.cancelOnce(kahfReminderIdBase + i);
  }
  if (!settings.kahfReminder || !await scheduler.hasPermission()) return;
  final l = lookupAppLocalizations(settings.locale ?? const Locale('ar'));
  final times = nextWeeklyTimes(
    now ?? DateTime.now(),
    weekday: DateTime.friday,
    minutes: kahfReminderMinutes,
    count: kahfRemindersAhead,
  );
  for (final (i, at) in times.indexed) {
    await scheduler.scheduleOnce(
      id: kahfReminderIdBase + i,
      at: at,
      title: l.kahfReminderTitle,
      body: l.kahfReminderBody,
      payload: kahfReminderLink,
      channel: l.kahfReminderChannel,
    );
  }
}
