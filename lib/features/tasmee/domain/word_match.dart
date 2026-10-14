import 'dart:math' as math;

/// How close a heard word must be to the expected one (after
/// normalization) to count as read correctly: the reader's setting
/// «صارم / متوسط / متسامح».
///
/// The score is 1 - (edit distance / length of the longer word).
enum MatchStrictness {
  /// The same word, letter for letter (after normalization).
  strict(1),

  /// One letter off in a word of five letters or more (a recogniser's slip
  /// on a long word); a short word must be exact. يعلمون / تعلمون (six
  /// letters, one apart) passes here, so a reader who wants such slips
  /// caught chooses [strict]. A leading و، ف، ب or ال dropped or added
  /// ([differsByLeadingPrefix]) is an error here all the same.
  medium(0.8),

  /// About one letter in three off; a leading و، ف، ب or ال dropped or
  /// added is only doubtful.
  lenient(0.65);

  const MatchStrictness(this.threshold);

  final double threshold;
}

/// Levenshtein distance between [a] and [b], by UTF-16 code unit (the
/// normalized keys are plain Arabic letters, one unit each).
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= b.length; j++) {
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    final t = previous;
    previous = current;
    current = t;
  }
  return previous[b.length];
}

/// 1 for the same key, down to 0 for keys with nothing in common.
double wordSimilarity(String a, String b) {
  if (a == b) return 1;
  final longer = math.max(a.length, b.length);
  if (longer == 0) return 1;
  return 1 - editDistance(a, b) / longer;
}

/// The prefixes whose dropping or adding is a known error of memorisation
/// (وإنهم / إنهم، فذوقوا / ذوقوا، العذاب / عذاب), as matching keys.
const leadingPrefixes = ['و', 'ف', 'ب', 'ال'];

/// Whether the matching keys [a] and [b] are the same word but for one
/// leading [leadingPrefixes] that one of them has and the other has not,
/// before at least two letters.
bool differsByLeadingPrefix(String a, String b) {
  if (a == b) return false;
  final (longer, shorter) = a.length > b.length ? (a, b) : (b, a);
  if (shorter.length < 2) return false;
  for (final p in leadingPrefixes) {
    if (longer.length == shorter.length + p.length &&
        longer.startsWith(p) &&
        longer.endsWith(shorter)) {
      return true;
    }
  }
  return false;
}
