import 'dart:math' as math;
import 'dart:typed_data';

class SpeechActivityFrame {
  const SpeechActivityFrame({
    required this.level,
    required this.audio,
    required this.speechEnded,
  });

  final double level;
  final List<Int16List> audio;
  final bool speechEnded;
}

/// Small in-memory energy VAD. Keeps a short pre-roll so the first consonant
/// is not lost, and ends a speech segment after sustained quiet. It stores no
/// audio outside the bounded pre-roll buffer.
///
/// The thresholds adapt to the room and to the reader's voice. Over the last
/// [windowMilliseconds] it tracks the noise floor (the [floorPercentile]
/// of frame levels) and the voice level (the [peakPercentile]). A frame is
/// quiet below the silence threshold: the highest of [minSilence], the
/// floor times [floorFactor], and the voice level times [peakRatio]. So a
/// breath between verses read aloud counts as a pause even when it is far
/// above the room's silence. Speech starts only above the silence threshold
/// times [hysteresis] (and at least [threshold]), so a level hovering near
/// the boundary does not flip the state frame by frame. The start threshold
/// follows the room's noise only (not the voice), so a soft syllable after
/// a pause is never dropped. Until half a second of levels is known, the
/// absolute thresholds apply.
class SpeechActivityDetector {
  SpeechActivityDetector({
    this.sampleRate = 16000,
    this.frameMilliseconds = 20,
    this.threshold = 0.012,
    this.minSilence = 0.006,
    this.floorFactor = 2.5,
    this.peakRatio = 0.05,
    this.hysteresis = 1.6,
    this.windowMilliseconds = 8000,
    this.floorPercentile = 0.03,
    this.peakPercentile = 0.9,
    this.preRollMilliseconds = 300,
    this.endSilenceMilliseconds = 300,
  }) : assert(sampleRate > 0),
       assert(frameMilliseconds > 0),
       assert(threshold > 0),
       assert(minSilence > 0),
       assert(floorFactor >= 1),
       assert(peakRatio >= 0 && peakRatio < 1),
       assert(hysteresis >= 1),
       assert(windowMilliseconds >= frameMilliseconds),
       assert(floorPercentile >= 0 && floorPercentile < peakPercentile),
       assert(peakPercentile <= 1),
       assert(preRollMilliseconds >= 0),
       assert(endSilenceMilliseconds >= frameMilliseconds);

  final int sampleRate;
  final int frameMilliseconds;

  /// The lowest level that may start speech, however quiet the room.
  final double threshold;

  /// The lowest silence threshold, however quiet the room and the voice.
  final double minSilence;

  /// The silence threshold stays this far above the noise floor.
  final double floorFactor;

  /// A frame below this share of the voice level is quiet (a breath).
  final double peakRatio;

  /// Speech starts above the silence threshold times this.
  final double hysteresis;

  /// The levels the floor and the voice level are measured over.
  final int windowMilliseconds;
  final double floorPercentile;
  final double peakPercentile;
  final int preRollMilliseconds;
  final int endSilenceMilliseconds;

  int get frameSamples => sampleRate * frameMilliseconds ~/ 1000;
  int get _preRollFrames => preRollMilliseconds ~/ frameMilliseconds;
  int get _endSilenceFrames =>
      (endSilenceMilliseconds + frameMilliseconds - 1) ~/ frameMilliseconds;
  int get _windowFrames => windowMilliseconds ~/ frameMilliseconds;
  static const _learnMilliseconds = 500;

  final List<Int16List> _preRoll = [];
  final List<double> _levels = [];
  bool _inSpeech = false;
  int _quietFrames = 0;
  double _silence = 0;
  double _floorSilence = 0;

  /// The current silence threshold (a frame below it is quiet).
  double get silenceThreshold => _silence;

  /// The current threshold speech must reach to start: from the room's
  /// noise only, so no quiet syllable is dropped between pauses.
  double get speechThreshold => math.max(threshold, _floorSilence * hysteresis);

  bool get inSpeech => _inSpeech;

  SpeechActivityFrame addFrame(Int16List frame) {
    if (frame.length != frameSamples) {
      throw ArgumentError.value(
        frame.length,
        'frame.length',
        'Expected $frameSamples PCM samples',
      );
    }
    final level = _rms(frame);
    _track(level);
    if (!_inSpeech) {
      if (_preRollFrames > 0) {
        _preRoll.add(frame);
        if (_preRoll.length > _preRollFrames) _preRoll.removeAt(0);
      }
      if (level < speechThreshold) {
        return SpeechActivityFrame(
          level: level,
          audio: const [],
          speechEnded: false,
        );
      }
      _inSpeech = true;
      _quietFrames = 0;
      final audio = [..._preRoll];
      if (_preRoll.isEmpty) audio.add(frame);
      _preRoll.clear();
      return SpeechActivityFrame(
        level: level,
        audio: audio,
        speechEnded: false,
      );
    }

    if (level < _silence) {
      _quietFrames++;
    } else {
      _quietFrames = 0;
    }
    final ended = _quietFrames >= _endSilenceFrames;
    if (ended) {
      _inSpeech = false;
      _quietFrames = 0;
      _preRoll.clear();
    }
    return SpeechActivityFrame(
      level: level,
      audio: [frame],
      speechEnded: ended,
    );
  }

  /// Ends the current stretch when the user presses stop.
  bool finish() {
    final wasInSpeech = _inSpeech;
    reset();
    return wasInSpeech;
  }

  /// Forgets the levels too: the next session may be in another room.
  void reset() {
    _preRoll.clear();
    _levels.clear();
    _silence = 0;
    _floorSilence = 0;
    _inSpeech = false;
    _quietFrames = 0;
  }

  /// Adds [level] to the window and updates the silence threshold.
  void _track(double level) {
    _levels.add(level);
    if (_levels.length > _windowFrames) _levels.removeAt(0);
    final sorted = [..._levels]..sort();
    double at(double q) => sorted[((sorted.length - 1) * q).round()];
    // Too few levels yet to tell the room from the voice: the absolute
    // thresholds only.
    final known = _levels.length * frameMilliseconds >= _learnMilliseconds;
    final floor = known ? at(floorPercentile) : 0.0;
    final voice = known ? at(peakPercentile) : 0.0;
    _floorSilence = math.max(minSilence, floor * floorFactor);
    _silence = math.max(_floorSilence, voice * peakRatio);
  }

  double _rms(Int16List frame) {
    var sum = 0.0;
    for (final sample in frame) {
      final normalized = sample / 32768.0;
      sum += normalized * normalized;
    }
    return math.sqrt(sum / frame.length);
  }
}
