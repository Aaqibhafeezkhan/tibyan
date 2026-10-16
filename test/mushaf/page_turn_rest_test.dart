import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/page_turn_effect.dart';

/// A page at rest takes its snapshot for the next turn when nothing
/// animates. It once asked for an idle-priority task, which an animation
/// running beside it put back on the event loop at once, forever: under a
/// test's fake clock the pump never returned (the whole reader's tests hung
/// once «طي الصفحة» became the default).
void main() {
  for (final effect in PageTurn.values) {
    testWidgets('at rest beside an endless animation: ${effect.name}', (
      tester,
    ) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: 3,
                itemBuilder: (context, i) => PageTurnEffect(
                  controller: controller,
                  index: i,
                  effect: effect,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(child: Text('page $i')),
                  ),
                ),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('page 0'), findsOneWidget);
      // The animation stops: the snapshot is taken after the next frame.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
