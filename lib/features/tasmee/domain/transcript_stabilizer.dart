import 'dart:math' as math;

import 'arabic_normalizer.dart';

/// Turns a streaming recogniser's changing hypotheses into words that are
/// settled, so the alignment only ever sees words that will not change.
///
/// A streaming recogniser transcribes the current stretch of speech again
/// and again as audio arrives, and the last words of each hypothesis often
/// change (a word cut in half, then completed). A word is settled once it
/// has stayed the same, at the same place, in [agreement] hypotheses in a
/// row, and every word before it is settled; or when the stretch ends
/// ([finish]). Words are compared by their matching keys, so a change in
/// vowel marks alone does not unsettle a word.
class TranscriptStabilizer {
  TranscriptStabilizer({this.agreement = 2}) : assert(agreement >= 1);

  final int agreement;

  List<String> _words = const [];
  List<String> _keys = const [];
  List<int> _runs = const [];
  int _settled = 0;

  /// Words of the current hypothesis that are not settled yet.
  List<String> get tentative =>
      _words.sublist(_settled.clamp(0, _words.length));

  /// The whole hypothesis for the current stretch of speech so far; returns
  /// the words that became settled with it, in order.
  List<String> update(String hypothesis) {
    final words = hypothesis.split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final keys = [for (final w in words) normalizeArabicWord(w)];
    final runs = [
      for (var i = 0; i < words.length; i++)
        i < _keys.length && _keys[i] == keys[i] ? _runs[i] + 1 : 1,
    ];
    _words = words;
    _keys = keys;
    _runs = runs;
    var stable = 0;
    while (stable < runs.length && runs[stable] >= agreement) {
      stable++;
    }
    if (stable <= _settled) return const [];
    final out = words.sublist(_settled, stable);
    _settled = stable;
    return out;
  }

  /// The stretch of speech ended with [finalText] (the recogniser's final
  /// result for it, or the last hypothesis when null): returns its words
  /// not settled yet, and starts afresh for the next stretch.
  List<String> finish([String? finalText]) {
    final words = finalText == null
        ? _words
        : (finalText.split(RegExp(r'\s+'))..removeWhere((w) => w.isEmpty));
    final out = _settled < words.length
        ? words.sublist(_settled)
        : const <String>[];
    _words = const [];
    _keys = const [];
    _runs = const [];
    _settled = 0;
    return out;
  }
}

/// How close a heard matching key is to the words the reader is expected
/// to say around where they are, 0..1 (1: one of them, letter for letter).
typedef ExpectedSimilarity = double Function(String key);

/// Joins again a word that a cut between two segments split in two.
///
/// A segment longer than the recogniser can take is cut at its quietest
/// moment (`SpeechSegmentBuffer`), and the next segment repeats a little
/// audio before the cut. When the cut falls inside a word, the recogniser
/// writes its two halves as two words, one at the end of a segment and one
/// at the start of the next («ٱلۡمُؤۡمِن» + «ؤۡمِنِينَ», «ي» + «يحملون»),
/// and the halves would be judged as errors.
///
/// So the last word of each segment that is not, letter for letter, a word
/// expected around the reader is held back until the next segment arrives
/// ([add]). It is then joined with that segment's first word when the
/// join matches an expected word better than either half does on its own,
/// and at least at the [threshold] of the reader's setting. Two joins are
/// tried: the halves one after the other, and the halves with the overlap
/// heard twice written once (the tail's last letters that start the head).
/// A tail that the head merely repeats (the overlap alone) is dropped.
///
/// Matching keys are compared ([normalizeArabicWord]). The joined word is
/// the head as written when the tail only repeated its start, the two
/// written halves together when nothing overlapped, and otherwise the
/// joined matching key (vowel marks are lost; it is only compared, and
/// shown as what was heard for a wrong word). The expected text is never
/// touched.
class SegmentJoiner {
  SegmentJoiner({required this.similarity, required this.threshold})
    : assert(threshold > 0 && threshold <= 1);

  final ExpectedSimilarity similarity;

  /// The reader's setting (`MatchStrictness.threshold`).
  final double threshold;

  String? _held;

  /// The last word of the previous segment, held back.
  String? get held => _held;

  /// The words of one finished segment; returns the words ready for the
  /// alignment, in order.
  List<String> add(List<String> segment) {
    final out = <String>[];
    var words = [
      for (final w in segment)
        if (normalizeArabicWord(w).isNotEmpty) w,
    ];
    final tail = _held;
    _held = null;
    if (tail != null) {
      final joined = words.isEmpty ? null : _join(tail, words.first);
      if (joined != null) {
        words = [joined, ...words.skip(1)];
      } else {
        out.add(tail);
      }
    }
    if (words.isEmpty) return out;
    final last = words.last;
    if (similarity(normalizeArabicWord(last)) >= 1) {
      out.addAll(words);
    } else {
      out.addAll(words.take(words.length - 1));
      _held = last;
    }
    return out;
  }

  /// The reader stopped or the session ends: the word held back, if any.
  List<String> flush() {
    final tail = _held;
    _held = null;
    return tail == null ? const [] : [tail];
  }

  void clear() => _held = null;

  String? _join(String tail, String head) {
    final t = normalizeArabicWord(tail), h = normalizeArabicWord(head);
    final alone = math.max(similarity(t), similarity(h));
    // The longest overlap first: on a tie it is the likelier join.
    final candidates = <String, String>{};
    for (var k = math.min(t.length, h.length); k >= 1; k--) {
      if (t.endsWith(h.substring(0, k))) {
        final key = joinKeys([t, h.substring(k)]);
        candidates.putIfAbsent(
          key,
          () => k == t.length ? head : (k == h.length ? tail : key),
        );
      }
    }
    candidates.putIfAbsent(joinKeys([t, h]), () => '$tail$head');
    String? best;
    var score = 0.0;
    for (final MapEntry(:key, :value) in candidates.entries) {
      final s = similarity(key);
      if (s > score) {
        score = s;
        best = value;
      }
    }
    if (best == null || score < threshold || score < alone) return null;
    // A tail that is itself an expected word only joins into a better one.
    if (similarity(t) >= score) return null;
    return best;
  }
}
