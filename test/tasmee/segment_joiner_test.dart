import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/features/tasmee/data/tasmee_words_repository.dart';
import 'package:tibyan/features/tasmee/domain/alignment_engine.dart';
import 'package:tibyan/features/tasmee/domain/arabic_normalizer.dart';
import 'package:tibyan/features/tasmee/domain/expected_words.dart';
import 'package:tibyan/features/tasmee/domain/recitation_range.dart';
import 'package:tibyan/features/tasmee/domain/transcript_stabilizer.dart';
import 'package:tibyan/features/tasmee/domain/word_match.dart';

/// A joiner over a fixed list of expected keys (common spelling).
SegmentJoiner _joiner(String expected, {double threshold = 0.8}) {
  final keys = matchingWords(expected);
  return SegmentJoiner(
    similarity: (key) =>
        keys.fold(0.0, (best, k) => math.max(best, wordSimilarity(key, k))),
    threshold: threshold,
  );
}

void main() {
  group('SegmentJoiner', () {
    test('a word expected letter for letter is never held back', () {
      final j = _joiner('من المؤمنين بل بدا');
      expect(j.add(['من', 'المؤمنين']), ['من', 'المؤمنين']);
      expect(j.held, isNull);
    });

    test('halves of a word cut with the overlap heard twice are joined', () {
      final j = _joiner('ونكون من المؤمنين بل بدا لهم');
      expect(j.add(['وَنَكُونَ', 'مِنَ', 'الْمُؤْمِن']), ['وَنَكُونَ', 'مِنَ']);
      expect(j.held, 'الْمُؤْمِن');
      final out = j.add(['ؤْمِنِينَ', 'بَلْ', 'بَدَا']);
      expect(out.map(normalizeArabicWord), ['المومنين', 'بل', 'بدا']);
      expect(j.held, isNull);
    });

    test('a tail the next segment repeats is dropped', () {
      final j = _joiner('وهم يحملون أوزارهم');
      expect(j.add(['وَهُمْ', 'ي']), ['وَهُمْ']);
      expect(j.add(['يحملون', 'أوزارهم']), ['يحملون', 'أوزارهم']);
    });

    test('halves with no overlap are joined as they are', () {
      final j = _joiner('بما كنتم تكفرون');
      expect(j.add(['بِمَا', 'كُنْ']), ['بِمَا']);
      expect(j.add(['تُمْ', 'تَكْفُرُونَ']), ['كُنْتُمْ', 'تَكْفُرُونَ']);
    });

    test('two whole words are not joined', () {
      final j = _joiner('قالوا يا حسرتنا');
      // «قال» is held (not exact), but «يا» is a word of its own and the
      // join «قاليا» matches nothing.
      expect(j.add(['قال']), isEmpty);
      expect(j.add(['يا', 'حسرتنا']), ['قال', 'يا', 'حسرتنا']);
    });

    test('a wrong word at the end of a segment is held, then let go', () {
      final j = _joiner('ولا نكذب بآيات ربنا ونكون');
      expect(j.add(['بآيات', 'الله']), ['بآيات']);
      expect(j.add(['ونكون']), ['الله', 'ونكون']);
    });

    test('the join must reach the reader\'s setting', () {
      // «نذب» is one letter short of «نكذب»: below medium, within lenient.
      expect((_joiner('ولا نكذب بآيات')..add(['ن'])).add(['نذب', 'بآيات']), [
        'ن',
        'نذب',
        'بآيات',
      ]);
      final lenient = _joiner('ولا نكذب بآيات', threshold: 0.65)..add(['ن']);
      expect(lenient.add(['نذب', 'بآيات']), ['نذب', 'بآيات']);
    });

    test('flush gives back the word held, once', () {
      final j = _joiner('أفلا تعقلون');
      j.add(['أفلا', 'تعقلو']);
      expect(j.flush(), ['تعقلو']);
      expect(j.flush(), isEmpty);
    });
  });

  group('with the engine, on the words of content.db', () {
    late ContentDatabase db;
    late List<ExpectedWord> words;
    setUpAll(() async {
      db = ContentDatabase(
        NativeDatabase(
          File('assets/db/content.db'),
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
        ),
      );
      words = await TasmeeWordsRepository(db).expectedWords(
        const VerseRange(fromSurah: 6, fromAyah: 27, toSurah: 6, toAyah: 28),
      );
    });
    tearDownAll(() => db.close());

    WordStatus statusOf(TasmeeEngine e, int ayah, int word) =>
        e.statusOf(words.indexWhere((w) => w.ayah == ayah && w.word == word));

    // The recogniser's output for al-An'am 6:27-28 read correctly, cut in
    // the middle of «ٱلۡمُؤۡمِنِينَ» (a real recording).
    const segments = [
      'وَلَوْ تَرَى إِذْ وُقِفُوا عَلَى النَّارِ فَقَالُوا يَا لَيْتَنَا نُرَدُّ',
      'وَلَا نُكَذِّبَ بِآيَاتِ رَبِّنَا وَنَكُونَ مِنَ الْمُؤْمِن',
      'ؤْمِنِينَ بَلْ بَدَا لَهُمْ مَا كَانُوا يُخْفُونَ مِن قَبْلُ',
    ];

    for (final strictness in MatchStrictness.values) {
      test('a word cut in two is read correctly (${strictness.name})', () {
        final engine = TasmeeEngine(
          words,
          options: TasmeeEngineOptions(strictness: strictness),
        );
        final joiner = SegmentJoiner(
          similarity: engine.expectedSimilarity,
          threshold: strictness.threshold,
        );
        final stabilizer = TranscriptStabilizer();
        for (final s in segments) {
          engine.addWords(joiner.add(stabilizer.finish(s)));
        }
        engine
          ..addWords(joiner.flush())
          ..finish();
        expect(statusOf(engine, 27, 16), WordStatus.correct);
        expect(engine.extraWords, isEmpty);
        expect(statusOf(engine, 28, 1), WordStatus.correct);
      });
    }

    test('without the joiner the same cut is an error', () {
      final engine = TasmeeEngine(
        words,
        options: const TasmeeEngineOptions(strictness: MatchStrictness.strict),
      );
      final stabilizer = TranscriptStabilizer();
      for (final s in segments) {
        engine.addWords(stabilizer.finish(s));
      }
      engine.finish();
      expect(statusOf(engine, 27, 16), WordStatus.wrong);
    });
  });
}
