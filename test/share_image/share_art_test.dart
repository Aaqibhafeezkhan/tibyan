import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/share_image/share_art.dart';

void main() {
  const page = Rect.fromLTRB(0, 0, 345, 550);
  final bands = bandsOfCuts(page, [40, 80, 120, 160]);

  group('linesCrop', () {
    test('cuts at the bands around the lines kept, never inside one', () {
      final r = linesCrop(
        page: page,
        tops: bands.tops,
        bottoms: bands.bottoms,
        lines: {2, 1},
      );
      expect(r, const Rect.fromLTRB(0, 40, 345, 120));
    });

    test('the first and last lines reach the page edges', () {
      expect(
        linesCrop(
          page: page,
          tops: bands.tops,
          bottoms: bands.bottoms,
          lines: {0},
        ),
        const Rect.fromLTRB(0, 0, 345, 40),
      );
      expect(
        linesCrop(
          page: page,
          tops: bands.tops,
          bottoms: bands.bottoms,
          lines: {3, 4},
        ),
        const Rect.fromLTRB(0, 120, 345, 550),
      );
    });

    test('all lines, or none known: the whole page', () {
      for (final lines in [
        <int>{},
        {0, 1, 2, 3, 4},
        {9},
      ]) {
        expect(
          linesCrop(
            page: page,
            tops: bands.tops,
            bottoms: bands.bottoms,
            lines: lines,
          ),
          page,
        );
      }
    });
  });

  test('lineOfY: the band holding a point, else the nearest', () {
    expect(lineOfY(10, bands.tops, bands.bottoms), 0);
    expect(lineOfY(40, bands.tops, bands.bottoms), 1);
    expect(lineOfY(500, bands.tops, bands.bottoms), 4);
    expect(lineOfY(-5, bands.tops, bands.bottoms), 0);
    expect(lineOfY(600, bands.tops, bands.bottoms), 4);
  });

  test('pagesOfPlaces: pages in order, their lines and first surah', () {
    final pages = pagesOfPlaces({
      (2, 6, 1): (page: 3, line: 0),
      (2, 5, 3): (page: 2, line: 14),
      (2, 6, 2): (page: 3, line: 1),
      (3, 1, 1): (page: 50, line: 2),
      (2, 286, 1): (page: 49, line: 14),
    });
    expect([for (final p in pages) p.page], [2, 3, 49, 50]);
    expect(pages[1].lines, {0, 1});
    expect(pages[3].surah, 3);
  });
}
