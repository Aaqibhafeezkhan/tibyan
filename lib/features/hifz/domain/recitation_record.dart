import 'fsrs.dart';
import 'strength.dart';

/// How a session was recited.
enum RecitationKind {
  /// Aloud, heard by the tasmee on the device.
  voice,

  /// On the page, revealing words by touch.
  touch,

  /// A unit's recitation test from the hifz screen.
  test,
}

/// A verse recited with this accuracy or more is «متقن» (mastered).
const masteryThreshold = 0.9;

bool isMastered(double? accuracy) =>
    accuracy != null && accuracy >= masteryThreshold - 1e-9;

/// A word read wrong or skipped: its verse (`ayah.id`) and its number in
/// the verse. Never its text.
typedef WordSlip = ({int verse, int word, bool skipped});

/// One verse's result in a session.
class VerseResultRecord {
  const VerseResultRecord({
    required this.verse,
    required this.accuracy,
    this.words = 0,
    this.wrong = 0,
    this.skipped = 0,
    this.corrected = 0,
    this.doubtful = 0,
  });

  /// `ayah.id`.
  final int verse;

  /// Correct over judged, 0..1; null when nothing was judged (doubtful
  /// words count neither way).
  final double? accuracy;
  final int words, wrong, skipped, corrected, doubtful;

  bool get mastered => isMastered(accuracy);
}

/// What a session leaves in the record: no audio, no text.
class RecitationRecord {
  const RecitationRecord({
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.verses,
    this.slips = const [],
    this.sensitivity,
  });

  final RecitationKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<VerseResultRecord> verses;
  final List<WordSlip> slips;
  final String? sensitivity;

  int get fromVerse =>
      verses.map((v) => v.verse).reduce((a, b) => a < b ? a : b);
  int get toVerse => verses.map((v) => v.verse).reduce((a, b) => a > b ? a : b);

  /// Weighted by the verses' judged words where known, else the mean of
  /// the verses' accuracies.
  double? get accuracy {
    final judged = [
      for (final v in verses)
        if (v.accuracy != null) v,
    ];
    if (judged.isEmpty) return null;
    final weights = judged.fold<int>(
      0,
      (s, v) => s + (v.words - v.doubtful).clamp(0, 1 << 30),
    );
    if (weights == 0) {
      return judged.fold<double>(0, (s, v) => s + v.accuracy!) / judged.length;
    }
    return judged.fold<double>(
          0,
          (s, v) => s + v.accuracy! * (v.words - v.doubtful).clamp(0, 1 << 30),
        ) /
        weights;
  }
}

/// A verse's strength after a recitation: mastered (≥ 90%) raises it a
/// level, to at least good; below that it becomes weak, so it comes up for
/// review early. A verse with nothing judged keeps its strength.
Strength strengthAfterRecitation(Strength before, double? accuracy) {
  if (accuracy == null) return before;
  if (!isMastered(accuracy)) return Strength.weak;
  final up = Strength.of((before.level + 1).clamp(1, 4));
  return up.level < Strength.good.level ? Strength.good : up;
}

/// The FSRS grade a review unit gets from the verses of it recited: all
/// mastered is good (its review moves later); a mean of 75% or more is
/// hard; less is again (it comes back soon).
Grade? gradeFromAccuracies(Iterable<double?> accuracies) {
  final all = [for (final a in accuracies) ?a];
  if (all.isEmpty) return null;
  if (all.every(isMastered)) return Grade.good;
  final mean = all.reduce((a, b) => a + b) / all.length;
  return mean >= 0.75 ? Grade.hard : Grade.again;
}

/// A verse's state on the progress map.
enum VerseState {
  none,

  /// Marked memorized by hand, not recited yet: suggest reciting it.
  memorized,

  /// Its last recitation reached the threshold.
  mastered,

  /// Its last recitation fell short, or it is weak.
  needsReview,
}

VerseState verseState({required int? strength, required double? lastAccuracy}) {
  if (lastAccuracy != null) {
    return isMastered(lastAccuracy)
        ? VerseState.mastered
        : VerseState.needsReview;
  }
  if (strength == null || strength <= 0) return VerseState.none;
  return strength == Strength.weak.level
      ? VerseState.needsReview
      : VerseState.memorized;
}
