import 'package:flutter/foundation.dart';

/// What one count did.
enum CountEvent {
  /// One more.
  counted,

  /// The target was reached: the round closed and a new one began.
  roundClosed,
}

/// The misbaha's counter: the count in the current round, the rounds
/// closed, and the target of a round (null for none). Reaching the target
/// closes the round and starts the next at zero on its own.
@immutable
class TasbihCounter {
  const TasbihCounter({this.count = 0, this.rounds = 0, this.target});

  final int count;
  final int rounds;
  final int? target;

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
        TasbihCounter(count: 0, rounds: rounds + 1, target: t),
        CountEvent.roundClosed,
      );
    }
    return (
      TasbihCounter(count: next, rounds: rounds, target: t),
      CountEvent.counted,
    );
  }

  /// A new target starts the round again; the rounds closed stay.
  TasbihCounter withTarget(int? t) =>
      TasbihCounter(count: count, rounds: rounds, target: t)._fit();

  TasbihCounter reset() => TasbihCounter(target: target);

  TasbihCounter _fit() {
    final t = target;
    if (t != null && t > 0 && count >= t) {
      return TasbihCounter(count: 0, rounds: rounds + 1, target: t);
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is TasbihCounter &&
      other.count == count &&
      other.rounds == rounds &&
      other.target == target;

  @override
  int get hashCode => Object.hash(count, rounds, target);
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
