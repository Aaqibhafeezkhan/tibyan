import 'dart:math' as math;

/// «مشاركة كمقطع فيديو»: when everything happens in a recitation reel,
/// as the approved «ورد اليوم» reels have it (tools/video/ayah_reel.py and
/// ayah_reel_mushaf.html): an intro card, the verses on a mushaf page with
/// the recited word lit, then the closing card. Times are in seconds of
/// the video unless named otherwise.
abstract final class ReelTiming {
  static const fps = 30;
  static const intro = 2.0;
  static const outro = 3.5;

  /// Audio kept before the first verse's start.
  static const lead = 0.25;

  /// Audio kept after the last word, when the verse runs on longer.
  static const tail = 0.8;

  /// Reels on the big platforms stop at 90 seconds.
  static const maxLength = 90.0;

  static const fadeIn = 0.15;
  static const fadeOut = 0.3;
}

/// One verse's timing in its surah file, in milliseconds.
typedef VerseTime = ({int ayah, int startMs, int endMs});

/// One word's timing in its surah file, in milliseconds; [word] counts
/// from 1 within its verse.
typedef WordTime = ({int ayah, int word, int startMs, int endMs});

/// The part of the surah file a reel plays, and where it sits in the video.
class AudioCut {
  const AudioCut({
    required this.startMs,
    required this.endMs,
    required this.offset,
  });

  /// In the surah file.
  final int startMs;
  final int endMs;

  /// Where it starts in the video, in seconds.
  final double offset;

  double get seconds => (endMs - startMs) / 1000;
}

/// When something lights in the video: a word of a verse ([word] from 1),
/// or a whole verse ([word] null) for a reciter without word timings.
class ReelCue {
  const ReelCue({
    required this.ayah,
    required this.word,
    required this.start,
    required this.end,
  });

  /// Index of the verse in the reel (0 = the first verse chosen).
  final int ayah;
  final int? word;
  final double start;
  final double end;

  @override
  String toString() => 'ReelCue($ayah, $word, $start-$end)';
}

/// A reel's timeline.
class ReelTimeline {
  const ReelTimeline({
    required this.audio,
    required this.cues,
    required this.wordLevel,
    required this.bodyEnd,
    required this.total,
  });

  final AudioCut audio;

  /// Sorted by start.
  final List<ReelCue> cues;

  /// Whether [cues] are words (else whole verses).
  final bool wordLevel;

  /// When the verses give way to the closing card.
  final double bodyEnd;
  final double total;

  bool get tooLong => total > ReelTiming.maxLength;

  int get frameCount => (total * ReelTiming.fps).ceil();

  /// Builds the timeline of verses [first]..[last] from the surah file's
  /// verse [verses] and word [words] timings. [wordCounts] holds each
  /// chosen verse's number of words as the text has them: a verse whose
  /// word timings do not match it word for word lights whole, and so do
  /// all of them when any does not match. Null when a chosen verse has no
  /// timing.
  static ReelTimeline? build({
    required int first,
    required int last,
    required List<VerseTime> verses,
    List<WordTime> words = const [],
    Map<int, int> wordCounts = const {},
  }) {
    final byAyah = {for (final v in verses) v.ayah: v};
    for (var a = first; a <= last; a++) {
      if (!byAyah.containsKey(a)) return null;
    }
    final firstV = byAyah[first]!, lastV = byAyah[last]!;
    final chosen = [
      for (final w in words)
        if (w.ayah >= first && w.ayah <= last) w,
    ]..sort((a, b) => a.startMs.compareTo(b.startMs));
    var wordLevel = chosen.isNotEmpty;
    for (var a = first; a <= last && wordLevel; a++) {
      final n = chosen.where((w) => w.ayah == a).length;
      final want = wordCounts[a];
      if (n == 0 || (want != null && want != n)) wordLevel = false;
    }
    final startMs = math.max(
      0,
      firstV.startMs - (ReelTiming.lead * 1000).round(),
    );
    var endMs = lastV.endMs;
    if (wordLevel) {
      final lastWord = chosen.where((w) => w.ayah == last).last;
      endMs = math.min(
        endMs,
        lastWord.endMs + (ReelTiming.tail * 1000).round(),
      );
    }
    if (endMs <= startMs) return null;
    double at(int ms) => ReelTiming.intro + (ms - startMs) / 1000;
    final cues = wordLevel
        ? [
            for (final w in chosen)
              ReelCue(
                ayah: w.ayah - first,
                word: w.word,
                start: at(w.startMs),
                end: at(w.endMs),
              ),
          ]
        : [
            for (var a = first; a <= last; a++)
              ReelCue(
                ayah: a - first,
                word: null,
                start: at(byAyah[a]!.startMs),
                end: at(math.min(byAyah[a]!.endMs, endMs)),
              ),
          ];
    final body = (endMs - startMs) / 1000;
    final bodyEnd = ReelTiming.intro + body;
    return ReelTimeline(
      audio: AudioCut(startMs: startMs, endMs: endMs, offset: ReelTiming.intro),
      cues: cues,
      wordLevel: wordLevel,
      bodyEnd: bodyEnd,
      total: bodyEnd + ReelTiming.outro,
    );
  }

  /// The cue lit at [t]: the last one started (it stays lit through the
  /// reciter's pause), none before the first, and none once the last one
  /// has ended (a short grace after a word).
  int? cueAt(double t) {
    var lo = 0, hi = cues.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= t) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found < 0) return null;
    if (found == cues.length - 1 && t > cues[found].end + 0.15) return null;
    return found;
  }
}

double _clamp(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _ease(double x) => x * x * (3 - 2 * x);

/// Everything that changes between two frames; equal states draw the same
/// picture, so a frame equal to the one before is not drawn again.
class FrameState {
  const FrameState({
    required this.intro,
    required this.body,
    required this.outro,
    required this.pages,
    required this.cue,
  });

  /// Opacities in 1/255 steps.
  final int intro, body, outro;

  /// Each verse page's opacity, in 1/255 steps.
  final List<int> pages;
  final int? cue;

  @override
  bool operator ==(Object other) =>
      other is FrameState &&
      other.intro == intro &&
      other.body == body &&
      other.outro == outro &&
      other.cue == cue &&
      _same(other.pages, pages);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(intro, body, outro, cue, Object.hashAll(pages));
}

/// What frame [i] shows. [pageStarts] holds when each verse page after the
/// first comes in (its first cue's start).
FrameState frameAt(
  ReelTimeline tl,
  int i, {
  List<double> pageStarts = const [],
}) {
  final t = i / ReelTiming.fps;
  int q(double x) => (_clamp(x) * 255).round();
  final iIn = _ease(_clamp(t / 0.35));
  final iOut = 1 - _ease(_clamp((t - (ReelTiming.intro - 0.45)) / 0.45));
  final bIn = _ease(_clamp((t - (ReelTiming.intro - 0.3)) / 0.4));
  final bOut = 1 - _ease(_clamp((t - tl.bodyEnd) / 0.4));
  final oIn = _ease(_clamp((t - tl.bodyEnd - 0.25) / 0.45));
  final n = pageStarts.length + 1;
  final pages = <int>[
    for (var k = 0; k < n; k++)
      q(
        math.min(
          k == 0 ? 1.0 : _clamp((t - (pageStarts[k - 1] - 0.15)) / 0.3),
          k + 1 < n ? 1 - _clamp((t - (pageStarts[k] - 0.15)) / 0.3) : 1.0,
        ),
      ),
  ];
  final body = q(math.min(bIn, bOut));
  return FrameState(
    intro: q(math.min(iIn, iOut)),
    body: body,
    outro: q(oIn),
    pages: pages,
    // The lit word matters only while the verses show.
    cue: body == 0 ? null : tl.cueAt(t),
  );
}

/// The frames of [tl] as runs of equal frames: (first frame, how many).
List<(FrameState, int)> frameRuns(
  ReelTimeline tl, {
  List<double> pageStarts = const [],
}) {
  final out = <(FrameState, int)>[];
  for (var i = 0; i < tl.frameCount; i++) {
    final s = frameAt(tl, i, pageStarts: pageStarts);
    if (out.isNotEmpty && out.last.$1 == s) {
      out[out.length - 1] = (s, out.last.$2 + 1);
    } else {
      out.add((s, 1));
    }
  }
  return out;
}
