import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/features/hifz/data/memorize_prefs.dart';
import 'package:tibyan/features/hifz/domain/memorize_session.dart';
import 'package:tibyan/features/hifz/domain/strength.dart';

/// A verse of [n] words on one line, each word 10 wide, right to left.
Map<MemoWord, List<Rect>> _verse(int s, int a, int n, {double top = 0}) => {
  for (var w = 1; w <= n; w++)
    (s, a, w): [Rect.fromLTWH(200 - w * 12.0, top, 10, 8)],
};

void main() {
  group('hiding styles', () {
    final words = [for (var w = 1; w <= 8; w++) (2, 5, w)];

    test('all hides every word', () {
      final m = MemorizeSession();
      expect(words.every(m.isHidden), isTrue);
    });

    test('first word shows only the first word of each verse', () {
      final m = MemorizeSession(style: MaskStyle.firstWord);
      expect(m.isHidden((2, 5, 1)), isFalse);
      expect(words.skip(1).every(m.isHidden), isTrue);
    });

    test('first letter covers the first word but leaves its start', () {
      final m = MemorizeSession(style: MaskStyle.firstLetter);
      final boxes = _verse(2, 5, 3);
      expect(m.isHidden((2, 5, 1)), isTrue);
      expect(m.isCue((2, 5, 1)), isTrue);
      final masks = m.masksOn(boxes);
      final first = boxes[(2, 5, 1)]!.single;
      final cue = masks.firstWhere(
        (r) => r.top == first.top && r.left == first.left,
      );
      // The right 30 % (where an Arabic word starts) stays uncovered.
      expect(cue.right, closeTo(first.right - first.width * 0.3, 1e-9));
      expect(masks, contains(boxes[(2, 5, 2)]!.single));
    });

    test('alternate hides every other word, the verse opening visible', () {
      final m = MemorizeSession(style: MaskStyle.alternate);
      expect(
        [for (final w in words) m.isHidden(w)],
        [
          false, true, false, true, false, true, false, true, //
        ],
      );
    });

    test('progressive starts visible and hides more each repetition', () {
      final m = MemorizeSession(style: MaskStyle.progressive);
      var before = <MemoWord>{};
      expect(words.where(m.isHidden), isEmpty);
      for (var round = 1; round <= MemorizeSession.maxLevel; round++) {
        m.nextRound();
        final now = words.where(m.isHidden).toSet();
        expect(now.containsAll(before), isTrue, reason: 'nested');
        expect(now.length, greaterThan(before.length));
        before = now;
      }
      expect(before.length, words.length);
      // No further than all.
      m.nextRound();
      expect(m.level, MemorizeSession.maxLevel);
    });

    test('changing the style covers everything again', () {
      final m = MemorizeSession()..reveal((2, 5, 3));
      m.style = MaskStyle.alternate;
      expect(m.isRevealed((2, 5, 3)), isFalse);
    });
  });

  group('reveal', () {
    test('a word, a verse, all, and hide all', () {
      final m = MemorizeSession();
      m.reveal((1, 2, 3));
      expect(m.isHidden((1, 2, 3)), isFalse);
      expect(m.current, (surah: 1, ayah: 2));
      m.revealVerse((surah: 1, ayah: 4));
      expect(m.isHidden((1, 4, 9)), isFalse);
      m.revealVerses([(surah: 1, ayah: 5)]);
      expect(m.isHidden((1, 5, 1)), isFalse);
      m.hideAll();
      expect(m.isHidden((1, 2, 3)), isTrue);
      expect(m.isHidden((1, 4, 9)), isTrue);
    });

    test('a range of words in reading order', () {
      final boxes = {..._verse(2, 5, 4), ..._verse(2, 6, 3, top: 20)};
      final range = wordsBetween((2, 6, 2), (2, 5, 3), boxes.keys);
      expect(range, [(2, 5, 3), (2, 5, 4), (2, 6, 1), (2, 6, 2)]);
    });

    test('a scope of verses leaves the others visible', () {
      final m = MemorizeSession(
        scope: const MemorizeScope.verses(
          (surah: 2, ayah: 6),
          (surah: 2, ayah: 7),
        ),
      );
      expect(m.isHidden((2, 5, 1)), isFalse);
      expect(m.isHidden((2, 6, 1)), isTrue);
      expect(m.isHidden((2, 7, 4)), isTrue);
      expect(m.isHidden((2, 8, 1)), isFalse);
    });

    test('a verse without word boxes is covered whole until revealed', () {
      final m = MemorizeSession();
      final boxes = _verse(2, 5, 3);
      const verses = [(surah: 2, ayah: 5), (surah: 2, ayah: 6)];
      expect(m.wholeVersesOn(verses, boxes), {(surah: 2, ayah: 6)});
      m.revealVerse((surah: 2, ayah: 6));
      expect(m.wholeVersesOn(verses, boxes), isEmpty);
    });

    test('judging a verse keeps the result and shows the verse', () {
      final m = MemorizeSession()
        ..grade((surah: 2, ayah: 5), VerseResult.missed);
      expect(m.results, {(surah: 2, ayah: 5): VerseResult.missed});
      expect(m.isHidden((2, 5, 2)), isFalse);
    });
  });

  group('geometry', () {
    final boxes = _verse(2, 5, 4);

    test('masks are exactly the hidden words\' boxes', () {
      final m = MemorizeSession(style: MaskStyle.alternate);
      expect(m.masksOn(boxes).toSet(), {
        boxes[(2, 5, 2)]!.single,
        boxes[(2, 5, 4)]!.single,
      });
    });

    test('a touch finds the word under it, or the nearest within slop', () {
      final w3 = boxes[(2, 5, 3)]!.single;
      expect(memoWordAt(w3.center, boxes), (2, 5, 3));
      // In the gap between words 3 and 2, nearer word 3.
      final gap = Offset(w3.right + 0.5, w3.center.dy);
      expect(memoWordAt(gap, boxes), isNull);
      expect(memoWordAt(gap, boxes, slop: 2), (2, 5, 3));
      // Off the line: nothing.
      expect(memoWordAt(Offset(w3.center.dx, 50), boxes, slop: 2), isNull);
    });

    test('a mask covers its word with a margin, and its line is inside', () {
      const word = Rect.fromLTWH(10, 10, 40, 20);
      final m = maskBox(word);
      expect(m.contains(word.topLeft) && m.contains(word.bottomRight), isTrue);
      expect(m.top, lessThan(word.top));
      expect(m.bottom, greaterThan(word.bottom));
      final (a, b) = maskLine(m);
      expect(m.contains(a) && m.contains(b), isTrue);
    });

    test('a cue keeps the start of the rightmost piece only', () {
      const right = Rect.fromLTWH(50, 0, 20, 10);
      const left = Rect.fromLTWH(20, 0, 20, 10);
      final masks = cueMasks([left, right]);
      expect(masks, contains(left));
      expect(masks.last.right, 64);
    });
  });

  group('persistence', () {
    test('the hiding style and reveal by reciting are kept', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer make() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final a = make();
      expect(a.read(memorizePrefsProvider).style, MaskStyle.all);
      await a
          .read(memorizePrefsProvider.notifier)
          .setStyle(MaskStyle.alternate);
      await a.read(memorizePrefsProvider.notifier).setByVoice(true);
      a.dispose();
      final b = make();
      addTearDown(b.dispose);
      expect(b.read(memorizePrefsProvider).style, MaskStyle.alternate);
      expect(b.read(memorizePrefsProvider).byVoice, isTrue);
    });

    test('an unknown stored style falls back to all', () async {
      SharedPreferences.setMockInitialValues({'memorize.style': 'nope'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(memorizePrefsProvider).style, MaskStyle.all);
    });
  });
}
