import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/hifz/domain/memorize_session.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/page_interaction.dart';

import '../tasmee/tasmee_test_env.dart';

/// Memorization masks land on their words at any page size: the letters
/// under a mask are gone, the word beside it keeps its ink.
void main() {
  late TasmeeTestData data;
  setUpAll(() => data = TasmeeTestData.open());
  tearDownAll(() => data.close());

  for (final size in const [Size(400, 700), Size(820, 1180)]) {
    testWidgets('masks cover exactly their words at $size', (tester) async {
      final container = await tasmeeContainer(tester, data);
      final boxes = (await tester.runAsync(
        () => container.read(pageWordBoxesProvider(3).future),
      ))!;
      final memo = MemorizeSession(style: MaskStyle.alternate);
      final hidden = boxes[(2, 6, 2)]!;
      final shown = boxes[(2, 6, 1)]!;
      expect(memo.isHidden((2, 6, 2)), isTrue);
      expect(memo.isHidden((2, 6, 1)), isFalse);
      final screen = <Rect, Rect>{};
      final boundary = GlobalKey();
      final w = size.width.toInt(), h = size.height.toInt();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        tasmeeApp(
          container,
          MushafPage(
            page: 3,
            interaction: PageInteraction(
              selection: const {},
              marks: const {},
              onTap: () {},
              onVerseLongPress: (_) {},
              onMarkerTap: (_) {},
              onHandleDrag: (_, _) {},
              wordMasks: memo.masksOn({(2, 6, 1): shown, (2, 6, 2): hidden}),
              wordOverlay: (canvas, toScreen) {
                for (final r in [...hidden, ...shown]) {
                  screen[r] = toScreen(r);
                }
              },
            ),
          ),
          theme: tasmeeTheme(container, mode: ThemeModeId.light),
          boundary: boundary,
        ),
      );
      await settle(tester);
      final object =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await tester.runAsync(() async {
        final image = await object.toImage();
        final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return d!;
      }))!;
      int inkIn(Rect r) => _ink(bytes, w, h, r.deflate(1));
      expect(inkIn(screen[shown.first]!), greaterThan(20), reason: 'shown');
      expect(inkIn(screen[hidden.first]!), 0, reason: 'covered');
    });
  }
}

/// Dark pixels (the ink on light paper) inside [r].
int _ink(ByteData bytes, int w, int h, Rect r) {
  var n = 0;
  for (var y = r.top.ceil(); y < r.bottom.floor() && y < h; y++) {
    for (var x = r.left.ceil(); x < r.right.floor() && x < w; x++) {
      final i = (y * w + x) * 4;
      final lum =
          bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2);
      if (lum < 300) n++;
    }
  }
  return n;
}
