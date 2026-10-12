import '../../../core/db/user_database.dart';
import '../../khatma/domain/day.dart';
import '../../khatma/domain/khatma_plan.dart' show PageRange;
import '../../khatma/domain/khatmah.dart';
import '../../khatma/domain/planner.dart';
import '../../khatma/domain/quran_index.dart';
import '../domain/hifz_goal.dart';
import 'recitation_store.dart';

/// The goals with a reminder, active and not complete, each with the next
/// [days] days' portions in Madina pages: for the khatma reminders, which
/// schedule them with the khatmas' own (one engine, one notice budget).
Future<List<({HifzGoal goal, Map<Day, PageRange> portions, int minutes})>>
goalReminderPortions(
  UserDatabase db,
  QuranIndex index,
  Day today,
  int days,
  HifzGoal Function(HifzGoalRow row) goalOf,
) async {
  final rows = await db.watchHifzGoals().first;
  final mastered = await db.watchMasteredEvents().first;
  final planner = Planner(index);
  final snap = Snapper(index, index.madina1441, quarters: true);
  final out = <({HifzGoal goal, Map<Day, PageRange> portions, int minutes})>[];
  for (final r in rows) {
    final minutes = r.reminderTime;
    if (minutes == null) continue;
    final g = goalOf(r);
    if (g.status != KhatmahStatus.active) continue;
    final k = g.khatmah;
    final ledger = Ledger(k, g.credits(mastered), index);
    if (ledger.complete) continue;
    final plan = planner.upcoming(k, ledger, today, snap, count: days);
    out.add((
      goal: g,
      minutes: minutes,
      portions: {
        for (final MapEntry(key: d, value: w) in plan.entries)
          d: (
            from: index.madina1441.pageOf(w.from),
            to: index.madina1441.lastPageOf(w.to),
          ),
      },
    ));
  }
  return out;
}
