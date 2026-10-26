import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hifz/data/recitation_store.dart';
import '../mushaf/mushaf_providers.dart' show userDatabaseProvider;
import '../tasbih/tasbih_providers.dart' show tasbihLogProvider;
import 'domain/weekly_report.dart';
import 'khatma_providers.dart';

/// How many weeks back the report goes (the tasbih log keeps 30 days).
const weeklyReportWeeksBack = 3;

final _weekReadingProvider = StreamProvider.family(
  (ref, DateTime since) =>
      ref.watch(activityRepositoryProvider).watchReadingSince(since),
);

final _weekListeningProvider = StreamProvider.family(
  (ref, DateTime since) =>
      ref.watch(activityRepositoryProvider).watchListeningSince(since),
);

final _weekRecitationsProvider = StreamProvider.family(
  (ref, DateTime since) =>
      ref.watch(userDatabaseProvider).watchRecitationStartsSince(since),
);

final _weekVersesProvider = StreamProvider.family(
  (ref, DateTime since) =>
      ref.watch(userDatabaseProvider).watchRecitedVersesSince(since),
);

/// The weekly report [weeksBack] weeks before the current one; null while
/// it loads.
final weeklyReportProvider = Provider.family<WeeklyReport?, int>((
  ref,
  weeksBack,
) {
  final week = reportWeek(ref.watch(todayProvider), weeksBack: weeksBack);
  final since = week.first.start;
  final reading = ref.watch(_weekReadingProvider(since)).value;
  final listening = ref.watch(_weekListeningProvider(since)).value;
  final recitations = ref.watch(_weekRecitationsProvider(since)).value;
  final verses = ref.watch(_weekVersesProvider(since)).value;
  if (reading == null ||
      listening == null ||
      recitations == null ||
      verses == null) {
    return null;
  }
  // Optional sources: a missing khatma or tasbih log is an empty one.
  final statuses = ref.watch(khatmaStatusesProvider).value ?? const [];
  final log = ref.watch(tasbihLogProvider).value ?? const {};
  final sessions = {for (final (_, uuid) in recitations) uuid};
  return buildWeeklyReport(
    last: week.last,
    reading: [for (final r in reading) (r.startedAt, r.endedAt, r.pages)],
    listening: [for (final s in listening) (s.startedAt, s.seconds)],
    recitations: [for (final (t, _) in recitations) t],
    recitedVerses: [
      for (final (t, v, s) in verses)
        if (sessions.contains(s)) (t, v),
    ],
    tasbih: {
      for (final e in log.entries)
        e.key: e.value.values.fold(0, (a, d) => a + d.count),
    },
    khatmas: [
      for (final s in statuses)
        (
          title: s.khatmah.title,
          progress: s.progress,
          coveredWeight: s.ledger.coveredWeight,
          weightOn: s.ledger.weightOn,
        ),
    ],
  );
});
