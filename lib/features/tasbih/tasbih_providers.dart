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
    FutureProvider<({DhikrSource source, List<Dhikr> adhkar})>(
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

/// Today's total of every dhikr (the home tile).
final tasbihTodayProvider = Provider<int>((ref) {
  final today = ref
      .watch(tasbihLogProvider)
      .value?[tasbihDayKey(DateTime.now())];
  return today?.values.fold<int>(0, (a, e) => a + e.count) ?? 0;
});

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
    final dhikr = ref.watch(currentDhikrProvider)?.key;
    final p = ref.read(sharedPreferencesProvider);
    if (dhikr == null || p.getString(_of) != dhikr) {
      return TasbihCounter(target: target);
    }
    return TasbihCounter(
      count: p.getInt(_count) ?? 0,
      rounds: p.getInt(_rounds) ?? 0,
    ).withTarget(target);
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
      unawaited(syncWidget());
    }
    return event;
  }

  void _feedback(CountEvent event) {
    final s = _settings;
    if (s.haptics) {
      unawaited(
        event == CountEvent.roundClosed
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.lightImpact(),
      );
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
    final today = await ref.read(tasbihRepositoryProvider).dayCount(dhikr.key);
    await ref
        .read(tasbihPlatformProvider)
        .writeWidget(dhikr: dhikr.text, count: '$today', label: label);
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
