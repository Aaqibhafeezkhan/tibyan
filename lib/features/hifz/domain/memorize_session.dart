import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'recitation_test.dart' show TestVerse;
import 'strength.dart';

/// A word on a page: surah, verse and the word's number in its verse (the
/// keys of `pageWordBoxesProvider`).
typedef MemoWord = (int, int, int);

/// How memorization mode hides the words.
enum MaskStyle {
  /// Every word.
  all,

  /// Every word, but the first letter of each verse stays as a cue.
  firstLetter,

  /// Every word but the first of each verse.
  firstWord,

  /// Every other word (the second, fourth…), so the verse opens visible.
  alternate,

  /// All visible at first; each repetition hides more, until all are.
  progressive,
}

/// The verses memorization mode covers: a stretch of verses, or (null
/// ends) every verse on the pages shown.
class MemorizeScope {
  const MemorizeScope.pages() : from = null, to = null;
  const MemorizeScope.verses(TestVerse this.from, TestVerse this.to);

  final TestVerse? from;
  final TestVerse? to;

  bool get wholePage => from == null;

  static int _order(int s, int a) => s * 1000 + a;

  bool contains(int surah, int ayah) {
    if (from == null || to == null) return true;
    final x = _order(surah, ayah);
    final a = _order(from!.surah, from!.ayah);
    final b = _order(to!.surah, to!.ayah);
    return x >= math.min(a, b) && x <= math.max(a, b);
  }
}

/// One memorization session: which words are hidden by the style, which
/// the reader revealed, and how the reader judged each verse. Pure state;
/// the page draws [masksOn] over the word boxes. The Quran text itself is
/// never touched: words are only covered.
class MemorizeSession {
  MemorizeSession({
    MaskStyle style = MaskStyle.all,
    this.scope = const MemorizeScope.pages(),
  }) : _style = style,
       level = style == MaskStyle.progressive ? 0 : maxLevel;

  /// Progressive hiding: the repetitions until every word is hidden.
  static const maxLevel = 4;

  /// Of the first letter's word, the share (from its start, on the right)
  /// left uncovered as the cue.
  static const cueShare = 0.3;

  MaskStyle _style;
  MaskStyle get style => _style;
  MemorizeScope scope;

  /// Progressive hiding: how many repetitions so far (0: all visible).
  int level;

  final Set<MemoWord> _revealed = {};
  final Set<TestVerse> _revealedVerses = {};
  final Map<TestVerse, VerseResult> results = {};

  /// The verse the reader is on: the last one revealed into or judged.
  TestVerse? current;

  set style(MaskStyle s) {
    _style = s;
    level = s == MaskStyle.progressive ? 0 : maxLevel;
    hideAll();
  }

  /// Progressive hiding: each word's turn (0..3). Neighbouring words get
  /// different turns, so each repetition hides words spread over the
  /// verse: a quarter, then every other word, then three in four, then all.
  static int turnOf(MemoWord w) => const [0, 2, 1, 3][(w.$3 + w.$2) % 4];

  bool inScope(int surah, int ayah) => scope.contains(surah, ayah);

  /// Whether the style hides [w] (before the reader's reveals).
  bool hidesByStyle(MemoWord w) {
    if (!inScope(w.$1, w.$2)) return false;
    return switch (_style) {
      MaskStyle.all || MaskStyle.firstLetter => true,
      MaskStyle.firstWord => w.$3 != 1,
      MaskStyle.alternate => w.$3.isEven,
      MaskStyle.progressive => turnOf(w) < level,
    };
  }

  bool isRevealed(MemoWord w) =>
      _revealed.contains(w) ||
      _revealedVerses.contains((surah: w.$1, ayah: w.$2));

  bool isHidden(MemoWord w) => hidesByStyle(w) && !isRevealed(w);

  /// Only the cue of [w] shows (its first letter); the rest is covered.
  bool isCue(MemoWord w) => _style == MaskStyle.firstLetter && w.$3 == 1;

  /// A verse with no word boxes in this edition is covered whole while the
  /// style hides most of it.
  bool hidesWholeVerse(TestVerse v) =>
      inScope(v.surah, v.ayah) &&
      !_revealedVerses.contains(v) &&
      switch (_style) {
        MaskStyle.progressive => level >= 2,
        _ => true,
      };

  void reveal(MemoWord w) {
    _revealed.add(w);
    current = (surah: w.$1, ayah: w.$2);
  }

  void revealAll(Iterable<MemoWord> words) => _revealed.addAll(words);

  void revealVerse(TestVerse v) {
    _revealedVerses.add(v);
    current = v;
  }

  void hideVerse(TestVerse v) {
    _revealedVerses.remove(v);
    _revealed.removeWhere((w) => w.$1 == v.surah && w.$2 == v.ayah);
  }

  /// Reveals every verse in [verses] (the pages shown).
  void revealVerses(Iterable<TestVerse> verses) =>
      _revealedVerses.addAll(verses);

  void hideAll() {
    _revealed.clear();
    _revealedVerses.clear();
  }

  /// Progressive hiding: the next repetition hides more, and what was
  /// revealed is covered again. Other styles: everything is covered again.
  void nextRound() {
    if (_style == MaskStyle.progressive) {
      level = math.min(level + 1, maxLevel);
    }
    hideAll();
  }

  /// The reader judged [v]: it is shown whole and kept for the record.
  void grade(TestVerse v, VerseResult r) {
    results[v] = r;
    revealVerse(v);
  }

  /// The boxes to cover on a page (edition units), from its word boxes.
  List<Rect> masksOn(Map<MemoWord, List<Rect>> boxes) => [
    for (final MapEntry(key: w, value: rects) in boxes.entries)
      if (isHidden(w))
        if (isCue(w)) ...cueMasks(rects) else ...rects,
  ];

  /// The verses on a page to cover whole: in scope, hidden by the style,
  /// and without word boxes on the page.
  Set<TestVerse> wholeVersesOn(
    Iterable<TestVerse> verses,
    Map<MemoWord, List<Rect>> boxes,
  ) {
    final withWords = {for (final (s, a, _) in boxes.keys) (surah: s, ayah: a)};
    return {
      for (final v in verses)
        if (!withWords.contains(v) && hidesWholeVerse(v)) v,
    };
  }
}

/// The cover of a cue word: all but its first [MemorizeSession.cueShare]
/// from the right (Arabic reads right to left). A word in several pieces
/// keeps the cue on its first (rightmost) piece only.
List<Rect> cueMasks(List<Rect> rects) {
  if (rects.isEmpty) return const [];
  final first = rects.reduce((a, b) => a.right >= b.right ? a : b);
  return [
    for (final r in rects)
      if (identical(r, first))
        Rect.fromLTRB(
          r.left,
          r.top,
          r.right - r.width * MemorizeSession.cueShare,
          r.bottom,
        )
      else
        r,
  ];
}

/// The word at [p] (edition units): the box holding it, or else the
/// nearest box on the same line within [slop].
MemoWord? memoWordAt(
  Offset p,
  Map<MemoWord, List<Rect>> boxes, {
  double slop = 0,
}) {
  MemoWord? best;
  var bestDistance = double.infinity;
  for (final MapEntry(key: w, value: rects) in boxes.entries) {
    for (final r in rects) {
      if (r.contains(p)) return w;
      if (p.dy < r.top || p.dy > r.bottom) continue;
      final d = p.dx < r.left ? r.left - p.dx : p.dx - r.right;
      if (d <= slop && d < bestDistance) {
        bestDistance = d;
        best = w;
      }
    }
  }
  return best;
}

int compareWords(MemoWord a, MemoWord b) {
  if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
  if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
  return a.$3.compareTo(b.$3);
}

/// The words of [words] from [a] to [b] (either order), in reading order.
List<MemoWord> wordsBetween(MemoWord a, MemoWord b, Iterable<MemoWord> words) {
  final (lo, hi) = compareWords(a, b) <= 0 ? (a, b) : (b, a);
  return [
    for (final w in words)
      if (compareWords(w, lo) >= 0 && compareWords(w, hi) <= 0) w,
  ]..sort(compareWords);
}

/// A mask's box on screen from a word's box on screen: a little taller
/// than the letters (their marks reach above and below the box) and
/// a pixel wider, so no edge of a letter shows.
Rect maskBox(Rect word) => Rect.fromLTRB(
  word.left - 1,
  word.top - word.height * 0.2,
  word.right + 1,
  word.bottom + word.height * 0.2,
);

/// The faint line drawn in a mask, where the hidden words sit: from 15 %
/// to 85 % of its width, a little under its middle.
(Offset, Offset) maskLine(Rect mask) {
  final y = mask.top + mask.height * 0.62;
  final inset = math.min(mask.width * 0.15, 6.0);
  return (Offset(mask.left + inset, y), Offset(mask.right - inset, y));
}
