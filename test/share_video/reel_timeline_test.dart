import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/share_video/reel_painter.dart';
import 'package:tibyan/features/share_video/reel_timeline.dart';

void main() {
  const verses = <VerseTime>[
    (ayah: 1, startMs: 5000, endMs: 9000),
    (ayah: 2, startMs: 9000, endMs: 14000),
    (ayah: 3, startMs: 14000, endMs: 20000),
  ];
  const words = <WordTime>[
    (ayah: 1, word: 1, startMs: 5100, endMs: 6000),
    (ayah: 1, word: 2, startMs: 6000, endMs: 8000),
    (ayah: 2, word: 1, startMs: 9200, endMs: 10000),
    (ayah: 2, word: 2, startMs: 10000, endMs: 11500),
    (ayah: 3, word: 1, startMs: 14100, endMs: 15000),
  ];

  group('audio segment', () {
    test('starts a lead before the first verse, ends after its last word', () {
      final tl = ReelTimeline.build(
        first: 1,
        last: 2,
        verses: verses,
        words: words,
      )!;
      expect(tl.audio.startMs, 4750);
      // The verse runs to 14000; the last word ends at 11500 + tail.
      expect(tl.audio.endMs, 12300);
      expect(tl.audio.offset, ReelTiming.intro);
      expect(tl.bodyEnd, closeTo(2 + 7.55, 1e-9));
      expect(tl.total, closeTo(2 + 7.55 + 3.5, 1e-9));
    });

    test('verse level when there are no word timings', () {
      final tl = ReelTimeline.build(first: 2, last: 3, verses: verses)!;
      expect(tl.wordLevel, isFalse);
      expect(tl.audio.endMs, 20000);
      expect(tl.cues.map((c) => (c.ayah, c.word)), [(0, null), (1, null)]);
      expect(tl.cues.first.start, closeTo(2 + .25, 1e-9));
    });

    test('a verse whose words do not match the text lights whole', () {
      final tl = ReelTimeline.build(
        first: 1,
        last: 2,
        verses: verses,
        words: words,
        wordCounts: {1: 2, 2: 3},
      )!;
      expect(tl.wordLevel, isFalse);
    });

    test('no timing for a chosen verse: no reel', () {
      expect(ReelTimeline.build(first: 3, last: 4, verses: verses), isNull);
    });

    test('longer than 90 seconds is flagged', () {
      final long = ReelTimeline.build(
        first: 1,
        last: 1,
        verses: const [(ayah: 1, startMs: 0, endMs: 100000)],
      )!;
      expect(long.tooLong, isTrue);
      final short = ReelTimeline.build(first: 1, last: 1, verses: verses)!;
      expect(short.tooLong, isFalse);
    });
  });

  group('cues', () {
    final tl = ReelTimeline.build(
      first: 1,
      last: 2,
      verses: verses,
      words: words,
    )!;

    test('words in video time, verse index from the first chosen', () {
      expect(tl.cues, hasLength(4));
      expect(tl.cues[2].ayah, 1);
      expect(tl.cues[2].word, 1);
      expect(tl.cues[0].start, closeTo(2 + (5100 - 4750) / 1000, 1e-9));
    });

    test('a word stays lit through the pause; none before or after', () {
      expect(tl.cueAt(0), isNull);
      expect(tl.cueAt(tl.cues[1].end + 0.5), 1);
      expect(tl.cueAt(tl.cues.last.end + 0.1), 3);
      expect(tl.cueAt(tl.cues.last.end + 0.2), isNull);
    });
  });

  group('frame scheduling', () {
    final tl = ReelTimeline.build(
      first: 1,
      last: 2,
      verses: verses,
      words: words,
    )!;

    test('frame count covers the whole reel at 30 fps', () {
      expect(tl.frameCount, (tl.total * 30).ceil());
    });

    test('intro, body and outro in turn', () {
      final start = frameAt(tl, 0);
      expect((start.intro, start.body, start.outro), (0, 0, 0));
      final intro = frameAt(tl, 30);
      expect((intro.intro, intro.body), (255, 0));
      final body = frameAt(tl, (4 * 30));
      expect((body.intro, body.body, body.outro), (0, 255, 0));
      expect(body.cue, isNotNull);
      final end = frameAt(tl, tl.frameCount - 1);
      expect((end.body, end.outro), (0, 255));
      expect(end.cue, isNull);
    });

    test('equal frames are drawn once', () {
      final runs = frameRuns(tl);
      expect(runs.fold<int>(0, (a, r) => a + r.$2), tl.frameCount);
      // Far fewer pictures than frames: fades, word changes and holds.
      expect(runs.length, lessThan(tl.frameCount ~/ 3));
      for (var i = 1; i < runs.length; i++) {
        expect(runs[i].$1 == runs[i - 1].$1, isFalse);
      }
    });

    test('a second page fades in at its first word', () {
      final at = tl.cues[2].start;
      final before = frameAt(tl, ((at - 0.5) * 30).floor(), pageStarts: [at]);
      expect(before.pages, [255, 0]);
      final after = frameAt(tl, ((at + 0.3) * 30).ceil(), pageStarts: [at]);
      expect(after.pages, [0, 255]);
    });
  });

  test('verse words are split as the app numbers them', () {
    const v = ReelVerse(number: 1, displayText: 'ab cd ۞ ef ١');
    expect(v.words, ['ab', 'cd', 'ef']);
  });
}
