import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart' show digitsFamily;
import '../../../core/theme/interface_style.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../data/tasbih_repository.dart';
import '../tasbih_providers.dart';

/// «سجل الأيام»: each dhikr's total on each day of the last thirty, and
/// nothing more: no points, streaks or comparisons.
class TasbihLogScreen extends ConsumerWidget {
  const TasbihLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final log = ref.watch(tasbihLogProvider).value ?? const {};
    final names = {for (final d in ref.watch(adhkarProvider)) d.key: d.text};
    final digits = NumberFormatter(Localizations.localeOf(context));
    final now = DateTime.now();
    final today = tasbihDayKey(now);
    final yesterday = tasbihDayKey(now.subtract(const Duration(days: 1)));
    final format = DateFormat.MMMMEEEEd(l.localeName);
    String dayName(String key) => key == today
        ? l.tasbihToday
        : key == yesterday
        ? l.tasbihYesterday
        : digitsIn(format.format(DateTime.parse(key)), digits);

    return LookScaffold(
      maxWidth: ContentWidth.text,
      body: SafeArea(
        child: Column(
          children: [
            LookTopBar(title: l.tasbihLog),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  Text(l.tasbihLogHint, style: TextStyle(color: look.sub)),
                  const SizedBox(height: 16),
                  if (log.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        l.tasbihLogEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: look.sub),
                      ),
                    ),
                  for (final MapEntry(key: day, value: totals) in log.entries)
                    LookGroup(
                      icon: Icons.today_outlined,
                      title: dayName(day),
                      children: [
                        for (final MapEntry(key: k, value: v) in totals.entries)
                          ListTile(
                            title: Text(
                              names[k] ?? l.tasbihDeletedDhikr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: v.rounds == 0
                                ? null
                                : Text(
                                    l.tasbihRounds(v.rounds, digits(v.rounds)),
                                    style: TextStyle(color: look.sub),
                                  ),
                            trailing: Text(
                              digits(v.count),
                              semanticsLabel: l.tasbihTimes(
                                v.count,
                                digits(v.count),
                              ),
                              style: TextStyle(
                                fontFamily: digitsFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: look.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [s] with its Western digits in the reader's digits.
String digitsIn(String s, NumberFormatter digits) =>
    s.replaceAllMapped(RegExp(r'\d+'), (m) => digits(int.parse(m[0]!)));
