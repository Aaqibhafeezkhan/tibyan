import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/onboarding/page_turn_preview.dart';

Widget _previews({bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(
      body: Wrap(
        children: [
          for (final e in PageTurn.values)
            PageTurnPreview(
              key: ValueKey(e),
              effect: e,
              paper: const Color(0xFFFFFBF0),
              ink: const Color(0xFF231F20),
              accent: const Color(0xFFB08D3C),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('every effect loops through a whole turn and back', (
    tester,
  ) async {
    await tester.pumpWidget(_previews());
    for (var t = Duration.zero; t < PageTurnPreview.period * 2;) {
      const step = Duration(milliseconds: 80);
      await tester.pump(step);
      t += step;
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(PageTurnPreview), findsNWidgets(PageTurn.values.length));
    // Still animating: the loop repeats.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('stands still when animations are off', (tester) async {
    await tester.pumpWidget(_previews(still: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
