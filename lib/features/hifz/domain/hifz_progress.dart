import '../../khatma/domain/quran_index.dart';
import 'recitation_record.dart';
import 'strength.dart';

/// A verse's latest recitation: accuracy (0..1) and when.
typedef LatestRecitation = ({double? accuracy, DateTime at});

/// Progress over a run of verses (the whole mushaf, a surah or a juz).
class ProgressPart {
  ProgressPart(this.number, this.verses);

  /// The surah or juz number; 0 for the whole mushaf.
  final int number;
  final int verses;
  int memorized = 0;
  int mastered = 0;
  int needsReview = 0;
  DateTime? lastRecited;
  double _accuracySum = 0;
  int _accuracyCount = 0;

  /// Mean of its verses' latest accuracies; null when none was recited.
  double? get accuracy =>
      _accuracyCount == 0 ? null : _accuracySum / _accuracyCount;

  double get memorizedShare => verses == 0 ? 0 : memorized / verses;
  double get masteredShare => verses == 0 ? 0 : mastered / verses;

  void _add(VerseState s, LatestRecitation? r) {
    if (s != VerseState.none) memorized++;
    if (s == VerseState.mastered) mastered++;
    if (s == VerseState.needsReview) needsReview++;
    if (r != null) {
      if (r.accuracy != null) {
        _accuracySum += r.accuracy!;
        _accuracyCount++;
      }
      if (lastRecited == null || r.at.isAfter(lastRecited!)) {
        lastRecited = r.at;
      }
    }
  }
}

/// The three levels of progress: the whole, each surah and each juz, and
/// each verse's state for the map. Plain shares only.
class HifzProgress {
  HifzProgress._(
    this.states,
    this.overall,
    this.surahs,
    this.juzs,
    this.pagesMemorized,
    this.juzMemorized,
    this.accuracy30,
    this.unrecited,
  );

  /// [strengths] by `surah:ayah` (memorized by hand or by test); [latest]
  /// by `ayah.id`; [recent] the verse accuracies of the last 30 days.
  factory HifzProgress.of(
    QuranIndex index,
    Map<String, int> strengths,
    Map<int, LatestRecitation> latest,
    Iterable<double> recent,
  ) {
    final states = <int, VerseState>{};
    final overall = ProgressPart(0, index.ayahCount);
    final surahs = [
      for (var s = 1; s <= index.surahCount; s++)
        ProgressPart(s, index.ayahCountOf(s)),
    ];
    final juzVerses = List<int>.filled(30, 0);
    for (var id = 1; id <= index.ayahCount; id++) {
      juzVerses[index.juzOf(id) - 1]++;
    }
    final juzs = [
      for (var j = 1; j <= 30; j++) ProgressPart(j, juzVerses[j - 1]),
    ];
    final pageAll = <int, bool>{};
    var unrecited = 0;
    for (var id = 1; id <= index.ayahCount; id++) {
      final f = index.facts(id);
      final r = latest[id];
      final s = verseState(
        strength: strengths[verseRef(f.surah, f.ayah)],
        lastAccuracy: r?.accuracy,
      );
      if (s != VerseState.none) states[id] = s;
      if (s == VerseState.memorized) unrecited++;
      overall._add(s, r);
      surahs[f.surah - 1]._add(s, r);
      juzs[f.juz - 1]._add(s, r);
      pageAll[f.page] = (pageAll[f.page] ?? true) && s != VerseState.none;
    }
    final list = recent.toList();
    return HifzProgress._(
      states,
      overall,
      surahs,
      juzs,
      pageAll.values.where((v) => v).length,
      juzs.where((j) => j.memorized == j.verses && j.verses > 0).length,
      list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length,
      unrecited,
    );
  }

  /// Each memorized verse's state, by `ayah.id`.
  final Map<int, VerseState> states;
  final ProgressPart overall;
  final List<ProgressPart> surahs;
  final List<ProgressPart> juzs;

  /// Pages and juz all of whose verses are memorized (Madina 1441 pages).
  final int pagesMemorized;
  final int juzMemorized;

  /// Mean verse accuracy over the last 30 days; null with no recitation.
  final double? accuracy30;

  /// Verses memorized by hand and never recited: suggest reciting them.
  final int unrecited;
}
