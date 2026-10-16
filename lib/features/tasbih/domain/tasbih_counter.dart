import 'package:flutter/foundation.dart';

/// What one count did.
enum CountEvent {
  /// One more.
  counted,

  /// A stage of a dhikr said in stages ended and the next began.
  stageChanged,

  /// The target was reached: the round closed and a new one began.
  roundClosed,
}

/// The misbaha's counter: the count in the current round, the rounds
/// closed, and the target of a round (null for none). Reaching the target
/// closes the round and starts the next at zero on its own.
@immutable
class TasbihCounter {
  const TasbihCounter({
    this.count = 0,
    this.rounds = 0,
    this.target,
    this.stages,
  });

  final int count;
  final int rounds;
  final int? target;

  /// The counts of the stages of a dhikr said in stages (their sum is the
  /// target); null otherwise.
  final List<int>? stages;

  /// The stage the count is in, from 0; and how far into it.
  ({int index, int count, int of})? get stage {
    final st = stages;
    if (st == null || st.isEmpty) return null;
    var before = 0;
    for (var i = 0; i < st.length; i++) {
      if (count < before + st[i]) {
        return (index: i, count: count - before, of: st[i]);
      }
      before += st[i];
    }
    return (index: st.length - 1, count: st.last, of: st.last);
  }

  /// Every count of this session: closed rounds and the current one.
  int get total => rounds * (target ?? 0) + count;

  /// How far the current round is, 0..1; 0 with no target.
  double get progress {
    final t = target;
    if (t == null || t <= 0) return 0;
    return (count / t).clamp(0, 1).toDouble();
  }

  (TasbihCounter, CountEvent) tap() {
    final next = count + 1;
    final t = target;
    if (t != null && t > 0 && next >= t) {
      return (
        TasbihCounter(count: 0, rounds: rounds + 1, target: t, stages: stages),
        CountEvent.roundClosed,
      );
    }
    final after = TasbihCounter(
      count: next,
      rounds: rounds,
      target: t,
      stages: stages,
    );
    return (
      after,
      after.stage != null && after.stage!.index != stage!.index
          ? CountEvent.stageChanged
          : CountEvent.counted,
    );
  }

  /// A new target starts the round again; the rounds closed stay.
  TasbihCounter withTarget(int? t) => TasbihCounter(
    count: count,
    rounds: rounds,
    target: t,
    stages: stages,
  )._fit();

  /// Said in [counts] stages: the target is their sum.
  TasbihCounter withStages(List<int>? counts) => TasbihCounter(
    count: count,
    rounds: rounds,
    target: counts == null ? target : counts.fold<int>(0, (a, b) => a + b),
    stages: counts,
  )._fit();

  TasbihCounter reset() => TasbihCounter(target: target, stages: stages);

  TasbihCounter _fit() {
    final t = target;
    if (t != null && t > 0 && count >= t) {
      return TasbihCounter(
        count: 0,
        rounds: rounds + 1,
        target: t,
        stages: stages,
      );
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is TasbihCounter &&
      other.count == count &&
      other.rounds == rounds &&
      other.target == target &&
      listEquals(other.stages, stages);

  @override
  int get hashCode =>
      Object.hash(count, rounds, target, Object.hashAll(stages ?? const []));
}

/// Targets offered in one tap; any other is set with the ± buttons.
const tasbihPresetTargets = <int?>[33, 100, null];

/// The bounds of a custom target.
const tasbihMinTarget = 1;
const tasbihMaxTarget = 9999;

/// A target one step up or down: by one under 10, by 10 under 100, by 100
/// beyond. Null (no target) steps to 33.
int? stepTarget(int? current, {required bool up}) {
  if (current == null) return up ? 33 : null;
  final step = current < 10 || (!up && current <= 10)
      ? 1
      : current < 100 || (!up && current <= 100)
      ? 10
      : 100;
  final next = up ? current + step : current - step;
  if (next < tasbihMinTarget) return tasbihMinTarget;
  if (next > tasbihMaxTarget) return tasbihMaxTarget;
  return next;
}
