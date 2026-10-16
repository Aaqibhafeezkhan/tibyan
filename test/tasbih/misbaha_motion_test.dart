import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/tasbih/presentation/styles/misbaha_view.dart';
import 'package:tibyan/features/tasbih/tasbih_settings.dart';

const _size = Size(300, 600);

/// The misbaha alone, its count kept here as the counter would.
class _Host extends StatefulWidget {
  const _Host({
    required this.render,
    required this.animate,
    this.roundSize,
    this.start = 0,
    this.counted,
  });

  final MisbahaRender render;
  final bool animate;
  final int? roundSize;
  final int start;
  final ValueNotifier<int>? counted;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int count = widget.start;
  int counts = 0;

  /// A count made elsewhere (the volume buttons).
  void external() => setState(() => count = _next(count));

  int _next(int c) {
    final t = widget.roundSize;
    return t != null && c + 1 >= t ? 0 : c + 1;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Center(
      child: SizedBox.fromSize(
        size: _size,
        child: MisbahaView(
          material: BeadMaterial.amber,
          render: widget.render,
          animate: widget.animate,
          count: count,
          roundSize: widget.roundSize,
          onCount: () => setState(() {
            counts++;
            widget.counted?.value = counts;
            count = _next(count);
          }),
        ),
      ),
    ),
  );
}

double _phase(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MisbahaView),
      matching: find.byType(CustomPaint),
    ),
  );
  return switch (paint.painter) {
    final SuggestedMisbahaPainter p => p.phase.value,
    final RealMisbahaPainter p => p.phase.value,
    _ => throw StateError('no misbaha painter'),
  };
}

TerminalBead _terminal(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MisbahaView),
      matching: find.byType(CustomPaint),
    ),
  );
  return switch (paint.painter) {
    final SuggestedMisbahaPainter p => p.terminal,
    final RealMisbahaPainter p => p.terminal,
    _ => throw StateError('no misbaha painter'),
  };
}

/// Frames enough for an animation to run its course (its first frame only
/// starts its clock).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final render in MisbahaRender.values) {
    group(render.name, () {
      double travel() => render == MisbahaRender.real
          ? RealMisbahaPainter.travel(_size)
          : SuggestedMisbahaPainter.travel(_size);

      testWidgets('a tap moves the whole string one bead and counts', (
        tester,
      ) async {
        final counted = ValueNotifier(0);
        await tester.pumpWidget(
          _Host(render: render, animate: true, counted: counted),
        );
        await tester.tap(find.byType(MisbahaView));
        await tester.pump();
        expect(counted.value, 1);
        // On its way, then at rest one bead on: never back where it was.
        await tester.pump(const Duration(milliseconds: 60));
        expect(_phase(tester), greaterThan(0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_phase(tester), 1);
      });

      testWidgets('a pull short of 40% eases back and does not count', (
        tester,
      ) async {
        final counted = ValueNotifier(0);
        await tester.pumpWidget(
          _Host(render: render, animate: true, counted: counted),
        );
        final g = await tester.startGesture(
          tester.getCenter(find.byType(MisbahaView)),
        );
        // Past the slop, then to 30% of the way, slowly.
        for (var i = 0; i < 10; i++) {
          await g.moveBy(Offset(0, (20 + travel() * .3) / 10));
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(_phase(tester), inExclusiveRange(0, .4));
        await tester.pump(const Duration(milliseconds: 200));
        await g.up();
        await _settle(tester);
        expect(counted.value, 0);
        expect(_phase(tester), 0);
      });

      testWidgets('a pull past 40% goes over on release and counts', (
        tester,
      ) async {
        final counted = ValueNotifier(0);
        await tester.pumpWidget(
          _Host(render: render, animate: true, counted: counted),
        );
        final g = await tester.startGesture(
          tester.getCenter(find.byType(MisbahaView)),
        );
        for (var i = 0; i < 10; i++) {
          await g.moveBy(Offset(0, (20 + travel() * .55) / 10));
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(milliseconds: 200));
        await g.up();
        await _settle(tester);
        expect(counted.value, 1);
        expect(_phase(tester), 1);
      });

      testWidgets('fast taps queue and none is lost', (tester) async {
        final counted = ValueNotifier(0);
        await tester.pumpWidget(
          _Host(render: render, animate: true, counted: counted),
        );
        for (var i = 0; i < 12; i++) {
          await tester.tap(find.byType(MisbahaView));
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(counted.value, 12);
        await _settle(tester);
        expect(_phase(tester), 12);
      });

      testWidgets('reduce motion moves the string at once', (tester) async {
        await tester.pumpWidget(_Host(render: render, animate: false));
        await tester.tap(find.byType(MisbahaView));
        await tester.pump();
        expect(_phase(tester), 1);
      });

      testWidgets('counts made elsewhere move the string too', (tester) async {
        final counted = ValueNotifier(0);
        await tester.pumpWidget(
          _Host(render: render, animate: true, counted: counted),
        );
        final host = tester.state<_HostState>(find.byType(_Host));
        host
          ..external()
          ..external();
        await tester.pump();
        host.external();
        await _settle(tester);
        expect(_phase(tester), 3);
        expect(counted.value, 0);
      });

      testWidgets('the terminal bead closes each round', (tester) async {
        await tester.pumpWidget(
          _Host(render: render, animate: true, roundSize: 33, start: 31),
        );
        final terminal = _terminal(tester);
        // Count 31 of 33: the bead after the one at the gap ends the round,
        // and so does every 33rd after it.
        expect(terminal(0), isFalse);
        expect(terminal(1), isTrue);
        expect(terminal(34), isTrue);
        expect(terminal(2), isFalse);
      });
    });
  }
}
