import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart'
    show sharedPreferencesProvider;
import '../mushaf/mushaf_providers.dart' show userDatabaseProvider;
import 'data/tasbih_repository.dart';
import 'domain/dhikr.dart';
import 'domain/tasbih_counter.dart';
import 'platform/tasbih_platform.dart';
import 'tasbih_settings.dart';

final tasbihRepositoryProvider = Provider<TasbihRepository>(
  (ref) => TasbihRepository(ref.watch(userDatabaseProvider)),
);

final tasbihPlatformProvider = Provider<TasbihPlatform>(
  (ref) => ChannelTasbihPlatform(),
);

/// The app's adhkar and where they come from.
final appAdhkarProvider =
    FutureProvider<({List<DhikrSource> sources, List<Dhikr> adhkar})>(
      (ref) async => parseAppAdhkar(
        await rootBundle.loadString('assets/tasbih/adhkar.json'),
      ),
    );

final myAdhkarProvider = StreamProvider<List<Dhikr>>(
  (ref) => ref.watch(tasbihRepositoryProvider).watchMine(),
);

/// Every dhikr the misbaha offers: the app's, then the reader's.
final adhkarProvider = Provider<List<Dhikr>>(
  (ref) => [
    ...?ref.watch(appAdhkarProvider).value?.adhkar,
    ...?ref.watch(myAdhkarProvider).value,
  ],
);

/// The dhikr being counted: the one chosen, else the first.
final currentDhikrProvider = Provider<Dhikr?>((ref) {
  final all = ref.watch(adhkarProvider);
  final key = ref.watch(tasbihSettingsProvider.select((s) => s.dhikr));
  return all.where((d) => d.key == key).firstOrNull ?? all.firstOrNull;
});

final tasbihLogProvider = StreamProvider<Map<String, TasbihDayTotals>>(
  (ref) => ref.watch(tasbihRepositoryProvider).watchLog(),
);

/// Today's total of every dhikr (the home tile). Kept in the preferences
/// beside the log, so the home screen reads no database stream for it; the
/// misbaha sets it from the log whenever it opens.
final tasbihTodayProvider = NotifierProvider<TasbihToday, int>(TasbihToday.new);

class TasbihToday extends Notifier<int> {
  static const _key = 'tasbih.today';

  @override
  int build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    final today = tasbihDayKey(DateTime.now());
    if (saved == null || !saved.startsWith('$today:')) return 0;
    return int.tryParse(saved.substring(today.length + 1)) ?? 0;
  }

  void set(int total) {
    state = total;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_key, '${tasbihDayKey(DateTime.now())}:$total'),
    );
  }

  void add(int n) => set(build() + n);
}

final tasbihCounterProvider = NotifierProvider<TasbihController, TasbihCounter>(
  TasbihController.new,
);

/// The counter of the dhikr being counted. The round in progress is kept
/// (outside the backup's `settings.*`) so leaving the misbaha keeps it.
class TasbihController extends Notifier<TasbihCounter> {
  static const _count = 'tasbih.count', _rounds = 'tasbih.rounds';
  static const _of = 'tasbih.countOf';

  @override
  TasbihCounter build() {
    final target = ref.watch(tasbihSettingsProvider.select((s) => s.target));
    final current = ref.watch(currentDhikrProvider);
    final dhikr = current?.key;
    // A dhikr said in stages counts its own stages; the target is theirs.
    final stages = current?.stageCounts;
    final p = ref.read(sharedPreferencesProvider);
    if (dhikr == null || p.getString(_of) != dhikr) {
      return TasbihCounter(target: target).withStages(stages);
    }
    return TasbihCounter(
      count: p.getInt(_count) ?? 0,
      rounds: p.getInt(_rounds) ?? 0,
    ).withTarget(target).withStages(stages);
  }

  TasbihSettings get _settings => ref.read(tasbihSettingsProvider);

  /// One count: the log, the feedback and the widget. Returns what the
  /// count did, for the screen's ring and its announcement.
  Future<CountEvent> tap() async {
    final (next, event) = state.tap();
    state = next;
    _feedback(event);
    _save();
    final dhikr = ref.read(currentDhikrProvider);
    if (dhikr != null) {
      await ref
          .read(tasbihRepositoryProvider)
          .record(dhikr.key, rounds: event == CountEvent.roundClosed ? 1 : 0);
      // The widget and today's total (the home tile), from the log.
      if (ref.mounted) unawaited(syncWidget());
    }
    return event;
  }

  void _feedback(CountEvent event) {
    final s = _settings;
    if (s.haptics) {
      unawaited(switch (event) {
        CountEvent.roundClosed => HapticFeedback.heavyImpact(),
        CountEvent.stageChanged => HapticFeedback.mediumImpact(),
        CountEvent.counted => HapticFeedback.lightImpact(),
      });
    }
    if (s.sound) unawaited(ref.read(tasbihPlatformProvider).click());
  }

  /// Counts made by the widget or the lock-screen service, added to the
  /// current dhikr as if tapped here (rounds included), without feedback.
  Future<int> absorbPending() async {
    final n = await ref.read(tasbihPlatformProvider).takePending();
    if (n <= 0) return 0;
    var c = state;
    var closed = 0;
    for (var i = 0; i < n; i++) {
      final (next, e) = c.tap();
      if (e == CountEvent.roundClosed) closed++;
      c = next;
    }
    state = c;
    _save();
    final dhikr = ref.read(currentDhikrProvider);
    if (dhikr != null) {
      await ref
          .read(tasbihRepositoryProvider)
          .record(dhikr.key, count: n, rounds: closed);
      if (!ref.mounted) return n;
      ref.read(tasbihTodayProvider.notifier).add(n);
    }
    return n;
  }

  /// Starts the round over; the log keeps what was counted.
  void reset() {
    state = state.reset();
    _save();
  }

  void _save() {
    final p = ref.read(sharedPreferencesProvider);
    final dhikr = ref.read(currentDhikrProvider)?.key;
    if (dhikr == null) return;
    unawaited(p.setString(_of, dhikr));
    unawaited(p.setInt(_count, state.count));
    unawaited(p.setInt(_rounds, state.rounds));
  }

  /// Writes the widget's dhikr and today's count of it.
  Future<void> syncWidget({String label = ''}) async {
    final dhikr = ref.read(currentDhikrProvider);
    if (dhikr == null) return;
    final repo = ref.read(tasbihRepositoryProvider);
    final today = await repo.dayCount(dhikr.key);
    final total = await repo.dayTotal();
    // The misbaha may have closed while the log was read.
    if (!ref.mounted) return;
    ref.read(tasbihTodayProvider.notifier).set(total);
    await ref
        .read(tasbihPlatformProvider)
        .writeWidget(
          dhikr: dhikr.text,
          count: '$today',
          label: label,
          stages: dhikr.stageCounts?.join(',') ?? '',
          round: state.count,
        );
  }
}

/// For tests: a counter's state after [n] taps from empty.
@visibleForTesting
TasbihCounter tapTimes(TasbihCounter c, int n) {
  var out = c;
  for (var i = 0; i < n; i++) {
    out = out.tap().$1;
  }
  return out;
}
