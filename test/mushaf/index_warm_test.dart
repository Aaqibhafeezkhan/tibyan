import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/mushaf/presentation/index_warm.dart';

void main() {
  group('IndexJumpWarmer', () {
    late List<int> warmed;
    late List<Completer<void>> slots;
    late IndexJumpWarmer warmer;

    setUp(() {
      warmed = [];
      slots = [];
      warmer = IndexJumpWarmer(
        warm: (page) async => warmed.add(page),
        schedule: () {
          final c = Completer<void>();
          slots.add(c);
          return c.future;
        },
      );
    });

    Future<void> idle() async {
      for (final c in slots) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(Duration.zero);
    }

    test('a touch-down warms its page in the next idle slot', () async {
      warmer.touchDown(42);
      expect(warmer.target, 42);
      expect(warmed, isEmpty); // never in the touch's own frame
      await idle();
      expect(warmed, [42]);
    });

    test('a scroll before the idle slot drops the warm', () async {
      warmer.touchDown(42);
      warmer.cancel();
      expect(warmer.target, isNull);
      await idle();
      expect(warmed, isEmpty);
    });

    test('another row retargets: only the last page is warmed', () async {
      warmer.touchDown(42);
      warmer.touchDown(77);
      await idle();
      expect(warmed, [77]);
    });

    test('the same row twice is warmed once', () async {
      warmer.touchDown(5);
      warmer.touchDown(5);
      await idle();
      expect(warmed, [5]);
    });

    test('a failing warm is quiet', () async {
      final w = IndexJumpWarmer(
        warm: (_) => Future.error(StateError('no pack')),
        schedule: () async {},
      );
      w.touchDown(3);
      await Future<void>.delayed(Duration.zero);
    });
  });

  testWidgets('rows warm on touch-down; a scroll cancels', (tester) async {
    final touched = <int>[];
    final warmer = IndexJumpWarmer(
      warm: (page) async => touched.add(page),
      schedule: () async {},
    );
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndexWarmScope(
            warmer: warmer,
            child: ListView(
              children: [
                for (var p = 1; p <= 40; p++)
                  IndexWarmRow(
                    page: p,
                    child: ListTile(
                      title: Text('page $p'),
                      onTap: () => tapped.add(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // A tap: warmed from the touch-down, the row's own tap unchanged.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('page 3')),
    );
    expect(warmer.target, 3);
    await gesture.up();
    await tester.pump();
    expect(tapped, [3]);
    expect(touched, [3]);

    // A drag from a row: the warm is dropped as the list scrolls.
    final drag = await tester.startGesture(
      tester.getCenter(find.text('page 5')),
    );
    expect(warmer.target, 5);
    await drag.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(warmer.target, isNull);
    await drag.up();
    await tester.pumpAndSettle();
    expect(tapped, [3]);
  });
}
