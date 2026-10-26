import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/mushaf/presentation/fit_width_scroll.dart';

/// A 400-high viewport over a 1300-high page, with the followed box at [y].
Widget _page(double y, {bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(800, 400), disableAnimations: reduce),
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: 400,
        child: FitWidthScroll(
          child: SizedBox(
            height: 1300,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: y,
                  height: 40,
                  child: FollowMark(rect: Rect.fromLTWH(0, y, 1, 40)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

double _offset(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  tearDown(() => FitWidthScrollState.now = DateTime.now);

  testWidgets('a line in view stays put', (t) async {
    await t.pumpWidget(_page(100));
    await t.pumpAndSettle();
    expect(_offset(t), 0);
  });

  testWidgets('a line below the screen scrolls into view, smoothly', (t) async {
    await t.pumpWidget(_page(100));
    await t.pumpAndSettle();
    await t.pumpWidget(_page(900));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final mid = _offset(t);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(800));
    await t.pumpAndSettle();
    // A quarter of the way down: 900 - 400 * 0.25.
    expect(_offset(t), 800);
  });

  testWidgets('less motion: it jumps', (t) async {
    await t.pumpWidget(_page(100, reduce: true));
    await t.pumpAndSettle();
    await t.pumpWidget(_page(900, reduce: true));
    await t.pump();
    await t.pump();
    expect(_offset(t), 800);
  });

  testWidgets('a scroll by hand holds the following back a few seconds', (
    t,
  ) async {
    var clock = DateTime(2026);
    FitWidthScrollState.now = () => clock;
    await t.pumpWidget(_page(100));
    await t.pumpAndSettle();
    await t.drag(find.byType(Scrollable), const Offset(0, -50));
    await t.pumpAndSettle();
    final byHand = _offset(t);
    await t.pumpWidget(_page(900));
    await t.pumpAndSettle();
    expect(_offset(t), byHand);
    clock = clock.add(const Duration(seconds: 5));
    await t.pumpWidget(_page(950));
    await t.pumpAndSettle();
    expect(_offset(t), 850);
  });
}
