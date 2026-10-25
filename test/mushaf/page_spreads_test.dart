import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/mushaf/presentation/page_spreads.dart';

void main() {
  test('single pages: one page per index', () {
    const s = PageSpreads(first: 0, base: 1, pageCount: 604, spread: false);
    expect(s.indexOf(0), 0);
    expect(s.indexOf(604), 604);
    expect(s.pagesAt(5), [5]);
    expect(s.count, 605);
  });

  test('Madina: the cover alone, then 1–2, 3–4 … 603–604', () {
    const s = PageSpreads(first: 0, base: 1, pageCount: 604, spread: true);
    expect(s.pagesAt(0), [0]);
    expect(s.pagesAt(1), [1, 2]);
    expect(s.pagesAt(2), [3, 4]);
    expect(s.indexOf(2), 1);
    expect(s.indexOf(3), 2);
    expect(s.indexOf(604), 302);
    expect(s.pagesAt(302), [603, 604]);
    expect(s.count, 303);
  });

  test('Shamarly: its cover alone, then 2–3; an odd last page alone', () {
    const s = PageSpreads(first: 1, base: 2, pageCount: 523, spread: true);
    expect(s.pagesAt(0), [1]);
    expect(s.pagesAt(1), [2, 3]);
    expect(s.indexOf(523), s.count - 1);
    expect(s.pagesAt(s.count - 1), [522, 523]);
    const odd = PageSpreads(first: 1, base: 2, pageCount: 522, spread: true);
    expect(odd.pagesAt(odd.count - 1), [522]);
  });

  test('every page maps back to an index that shows it', () {
    const s = PageSpreads(first: 0, base: 1, pageCount: 604, spread: true);
    for (var p = 0; p <= 604; p++) {
      expect(s.pagesAt(s.indexOf(p)), contains(p));
    }
  });

  test('right pages: odd in the Madina editions, even in the Shamarly', () {
    const madina = PageSpreads(first: 0, base: 1, pageCount: 604, spread: true);
    expect(madina.isRightPage(1), isTrue);
    expect(madina.isRightPage(2), isFalse);
    expect(madina.isRightPage(603), isTrue);
    const shamarly = PageSpreads(
      first: 1,
      base: 2,
      pageCount: 523,
      spread: true,
    );
    expect(shamarly.isRightPage(2), isTrue);
    expect(shamarly.isRightPage(3), isFalse);
    // The right page of every spread is the first of its pair.
    for (var i = 1; i < madina.count; i++) {
      expect(madina.isRightPage(madina.pagesAt(i).first), isTrue);
    }
    for (var i = 1; i < shamarly.count; i++) {
      expect(shamarly.isRightPage(shamarly.pagesAt(i).first), isTrue);
    }
  });

  test('a jump lands on the spread that holds the page', () {
    const s = PageSpreads(first: 0, base: 1, pageCount: 604, spread: true);
    for (final p in [1, 2, 50, 51, 300, 603, 604]) {
      final pages = s.pagesAt(s.indexOf(p));
      expect(pages, contains(p));
      expect(pages.first.isOdd, isTrue);
    }
  });

  test('spreads only on a tablet or a desktop held sideways', () {
    expect(showsSpread(const Size(1366, 1024), largeDevice: true), isTrue);
    expect(showsSpread(const Size(1024, 1366), largeDevice: true), isFalse);
    expect(showsSpread(const Size(700, 500), largeDevice: true), isFalse);
    // A big phone sideways.
    expect(showsSpread(const Size(932, 430), largeDevice: false), isFalse);
  });

  test('a phone sideways fits the page to its width', () {
    expect(
      fitWidthHeight(const Size(932, 400), largeDevice: false),
      932 * 1.45,
    );
    expect(fitWidthHeight(const Size(393, 700), largeDevice: false), isNull);
    expect(fitWidthHeight(const Size(1366, 1000), largeDevice: true), isNull);
  });
}
