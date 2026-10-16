import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/tasbih/domain/tasbih_counter.dart';
import 'package:tibyan/features/tasbih/tasbih_providers.dart';

void main() {
  test('counts up within a round', () {
    final (c, e) = const TasbihCounter(target: 33).tap();
    expect(c.count, 1);
    expect(e, CountEvent.counted);
    expect(c.progress, closeTo(1 / 33, 1e-9));
  });

  test('reaching the target closes the round and starts a new one', () {
    var c = tapTimes(const TasbihCounter(target: 33), 32);
    expect(c.count, 32);
    final (next, e) = c.tap();
    expect(e, CountEvent.roundClosed);
    expect(next.count, 0);
    expect(next.rounds, 1);
    c = tapTimes(next, 33 * 2 + 5);
    expect(c.rounds, 3);
    expect(c.count, 5);
    expect(c.total, 3 * 33 + 5);
  });

  test('no target never closes a round', () {
    final c = tapTimes(const TasbihCounter(), 250);
    expect(c.count, 250);
    expect(c.rounds, 0);
    expect(c.progress, 0);
  });

  test('a lower target closes the round at once; reset keeps target', () {
    final c = tapTimes(const TasbihCounter(target: 100), 40).withTarget(33);
    expect(c.rounds, 1);
    expect(c.count, 0);
    expect(c.reset(), const TasbihCounter(target: 33));
  });

  test('± steps the target and keeps it in bounds', () {
    expect(stepTarget(null, up: true), 33);
    expect(stepTarget(null, up: false), null);
    expect(stepTarget(5, up: true), 6);
    expect(stepTarget(33, up: true), 43);
    expect(stepTarget(33, up: false), 23);
    expect(stepTarget(100, up: true), 200);
    expect(stepTarget(100, up: false), 90);
    expect(stepTarget(1, up: false), 1);
    expect(stepTarget(9999, up: true), 9999);
  });

  test('stages count in turn and the last closes the round', () {
    var c = const TasbihCounter().withStages([33, 33, 33, 1]);
    expect(c.target, 100);
    expect(c.stage, (index: 0, count: 0, of: 33));
    c = tapTimes(c, 32);
    final (atStage, e) = c.tap();
    expect(e, CountEvent.stageChanged);
    expect(atStage.stage, (index: 1, count: 0, of: 33));
    c = tapTimes(atStage, 66);
    expect(c.stage, (index: 3, count: 0, of: 1));
    final (closed, last) = c.tap();
    expect(last, CountEvent.roundClosed);
    expect(closed.rounds, 1);
    expect(closed.stage, (index: 0, count: 0, of: 33));
  });
}
