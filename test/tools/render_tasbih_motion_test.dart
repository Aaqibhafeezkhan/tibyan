import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/tasbih/presentation/styles/misbaha_view.dart';
import 'package:tibyan/features/tasbih/tasbih_settings.dart';

/// Not a test: films the misbaha's motion, frame by frame at 30 fps, into
/// `$TASBIH_MOTION_OUT/<render>/frame_0000.png…` (a short pull that eases
/// back, a pull that goes over, then quick taps over the round's end, the
/// terminal bead passing). Runs only with RENDER_TASBIH_MOTION=1; ffmpeg
/// makes the clips.
void main() {
  final run = Platform.environment['RENDER_TASBIH_MOTION'] == '1';
  final outPath =
      Platform.environment['TASBIH_MOTION_OUT'] ?? 'build/tasbih_motion';

  testWidgets(
    'film the misbaha motion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2;
      tester.view.devicePixelRatio = 2;
      for (final render in MisbahaRender.values) {
        final dir = Directory('$outPath/${render.name}')
          ..createSync(recursive: true);
        var count = 29;
        var frame = 0;
        final boundary = GlobalKey();
        late StateSetter set;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return ColoredBox(
                    color: const Color(0xFFF4F0E8),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Expanded(
                          child: MisbahaView(
                            material: BeadMaterial.amber,
                            render: render,
                            count: count,
                            roundSize: 33,
                            onCount: () => set(
                              () => count = count + 1 >= 33 ? 0 : count + 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        Future<void> shoot([int n = 1]) async {
          for (var i = 0; i < n; i++) {
            await tester.pump(const Duration(milliseconds: 33));
            final object =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final bytes = await tester.runAsync(() async {
              final image = await object.toImage(pixelRatio: 1);
              final d = await image.toByteData(format: ui.ImageByteFormat.png);
              image.dispose();
              return d!.buffer.asUint8List();
            });
            File(
              '${dir.path}/frame_${(frame++).toString().padLeft(4, '0')}.png',
            ).writeAsBytesSync(bytes!);
          }
        }

        await shoot(12);
        final view = find.byType(MisbahaView);
        final travel = render == MisbahaRender.real
            ? RealMisbahaPainter.travel(tester.getSize(view))
            : SuggestedMisbahaPainter.travel(tester.getSize(view));
        // A short pull (30%) that eases back.
        var g = await tester.startGesture(tester.getCenter(view));
        for (var i = 0; i < 12; i++) {
          await g.moveBy(Offset(0, (20 + travel * .3) / 12));
          await shoot();
        }
        await g.up();
        await shoot(12);
        // A pull past the middle that goes over.
        g = await tester.startGesture(tester.getCenter(view));
        for (var i = 0; i < 14; i++) {
          await g.moveBy(Offset(0, (20 + travel * .65) / 14));
          await shoot();
        }
        await g.up();
        await shoot(14);
        // Quick taps across the round's end: the terminal bead passes.
        for (var i = 0; i < 6; i++) {
          await tester.tap(view);
          await shoot(4);
        }
        await shoot(18);
      }
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
