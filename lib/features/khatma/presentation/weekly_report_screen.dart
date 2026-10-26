import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../domain/weekly_report.dart';
import '../khatma_providers.dart' show reminderSchedulerProvider;
import '../services/weekly_reminder.dart';
import '../weekly_report_providers.dart';

/// «التقرير الأسبوعي»: seven days of reading, listening, recitation, khatma
/// progress and tasbih, told calmly. A quiet week is a fresh start, never
/// a failure: nothing counts missed days or compares weeks.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportState();
}

class _WeeklyReportState extends ConsumerState<WeeklyReportScreen> {
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final report = ref.watch(weeklyReportProvider(_back));

    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.weeklyReportTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ContentWidth.text,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _WeekSwitcher(
                        back: _back,
                        report: report,
                        onChange: (b) => setState(() => _back = b),
                      ),
                      const SizedBox(height: 8),
                      if (report == null)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.wb_twilight_outlined,
                              color: t.goldText,
                            ),
                            title: Text(switch (report.note) {
                              WeeklyNote.freshStart => l.weeklyNoteFresh,
                              WeeklyNote.someDays => l.weeklyNoteSome,
                              WeeklyNote.mostDays => l.weeklyNoteMost,
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DailyChart(report: report),
                        const SizedBox(height: 12),
                        if (report.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: Text(
                              l.weeklyEmptyBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.muted),
                            ),
                          )
                        else
                          _Stats(
                            items: [
                              (l.weeklyActiveDays, report.activeDays),
                              (l.reportsPages, report.pages),
                              (l.reportsReadingMinutes, report.readingMinutes),
                              (
                                l.reportsListeningMinutes,
                                report.listeningMinutes,
                              ),
                              if (report.recitations > 0) ...[
                                (l.weeklyRecitations, report.recitations),
                                (l.weeklyVersesRecited, report.versesRecited),
                              ],
                              if (report.tasbih > 0)
                                (l.weeklyTasbih, report.tasbih),
                            ],
                            digits: digits,
                          ),
                        if (report.khatmas.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 4,
                              bottom: 6,
                            ),
                            child: Text(
                              l.weeklyKhatmas,
                              style: TextStyle(
                                color: t.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final k in report.khatmas)
                            _KhatmaCard(khatma: k),
                        ],
                      ],
                      const SizedBox(height: 16),
                      const WeeklyReminderTiles(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.back,
    required this.report,
    required this.onChange,
  });

  final int back;
  final WeeklyReport? report;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final m = MaterialLocalizations.of(context);
    final r = report;
    final range = r == null
        ? ''
        : l.weeklyRange(
            m.formatShortMonthDay(r.first.start),
            m.formatShortMonthDay(r.last.start),
          );
    // Icons follow the reading direction: «previous» points back.
    return Row(
      children: [
        IconButton(
          tooltip: l.weeklyPrevious,
          icon: const Icon(Icons.chevron_left),
          onPressed: back < weeklyReportWeeksBack
              ? () => onChange(back + 1)
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              if (back == 0)
                Text(
                  l.weeklyThisWeek,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              Text(
                range,
                style: TextStyle(color: t.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l.weeklyNext,
          icon: const Icon(Icons.chevron_right),
          onPressed: back > 0 ? () => onChange(back - 1) : null,
        ),
      ],
    );
  }
}

/// Minutes of reading and listening per day, oldest first in the reading
/// direction (right to left in Arabic). Empty days keep a plain track:
/// nothing marks them as missed.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final names = MaterialLocalizations.of(context).narrowWeekdays;
    final day = DateFormat.EEEE(l.localeName);
    final minutes = [
      for (final d in report.days)
        ((d.readingSeconds + d.listeningSeconds) / 60).round(),
    ];
    final most = math.max(1, minutes.fold(0, math.max));
    const height = 96.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.weeklyDailyChart,
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, d) in report.days.indexed)
                  Expanded(
                    child: MergeSemantics(
                      child: Semantics(
                        label: l.weeklyDayMinutes(
                          day.format(d.day.start),
                          digits(minutes[i]),
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Text(
                                minutes[i] > 0 ? digits(minutes[i]) : '',
                                style: TextStyle(color: t.muted, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 18,
                                height: height,
                                alignment: Alignment.bottomCenter,
                                decoration: BoxDecoration(
                                  color: t.border.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: minutes[i] == 0
                                      ? 0
                                      : math.max(0.08, minutes[i] / most),
                                  widthFactor: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: t.control,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                names[d.day.start.weekday % 7],
                                style: TextStyle(color: t.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.items, required this.digits});

  final List<(String, int)> items;
  final NumberFormatter digits;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: width,
                child: MergeSemantics(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            digits(value),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(color: t.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KhatmaCard extends StatelessWidget {
  const _KhatmaCard({required this.khatma});

  final KhatmaWeek khatma;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final digits = NumberFormatter(Localizations.localeOf(context));
    // Whole percents; a little read shows as at least 1%.
    String percent(double f) =>
        digits(f <= 0 ? 0 : math.max(1, (f * 100).round()));
    return MergeSemantics(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                khatma.title,
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: khatma.progress,
                    minHeight: 8,
                    color: t.control,
                    backgroundColor: t.border.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.weeklyKhatmaProgress(percent(khatma.progress)),
                style: TextStyle(color: t.muted, fontSize: 13),
              ),
              if (khatma.gained > 0)
                Text(
                  l.weeklyKhatmaGained(percent(khatma.gained)),
                  style: TextStyle(color: t.goldText, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The weekly reminder: a switch (off by default) and, when on, its day
/// and time. Shown on the report and in Settings > Khatma.
class WeeklyReminderTiles extends ConsumerWidget {
  const WeeklyReminderTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final s = ref.watch(settingsProvider);
    final day = DateFormat.EEEE(l.localeName);
    // 2024-01-01 was a Monday: weekday n falls on January n.
    String dayName(int weekday) => day.format(DateTime(2024, 1, weekday));
    final time = TimeOfDay(
      hour: s.weeklyReminderMinutes ~/ 60,
      minute: s.weeklyReminderMinutes % 60,
    );

    Future<void> resync() => syncWeeklyReminder(
      ref.read(reminderSchedulerProvider),
      ref.read(settingsProvider),
    );

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_none),
          title: Text(l.weeklyReminderToggle),
          subtitle: Text(
            l.weeklyReminderHint,
            style: TextStyle(color: t.muted),
          ),
          value: s.weeklyReminder,
          onChanged: (on) async {
            if (on) {
              await ref.read(reminderSchedulerProvider).requestPermission();
            }
            await ref.read(settingsProvider.notifier).setWeeklyReminder(on);
            await resync();
          },
        ),
        if (s.weeklyReminder)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l.weeklyReminderWhen),
            subtitle: Text(
              '${dayName(s.weeklyReminderWeekday)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(time)}',
            ),
            onTap: () async {
              final weekday = await showDialog<int>(
                context: context,
                builder: (c) => SimpleDialog(
                  title: Text(l.weeklyReminderWhen),
                  children: [
                    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(c, d),
                        child: Row(
                          children: [
                            Icon(
                              d == s.weeklyReminderWeekday
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: t.control,
                            ),
                            const SizedBox(width: 12),
                            Text(dayName(d)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              if (weekday == null || !context.mounted) return;
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              await ref
                  .read(settingsProvider.notifier)
                  .setWeeklyReminderTime(
                    weekday: weekday,
                    minutes: picked.hour * 60 + picked.minute,
                  );
              await resync();
            },
          ),
      ],
    );
  }
}
