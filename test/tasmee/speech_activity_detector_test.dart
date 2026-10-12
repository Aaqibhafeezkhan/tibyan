import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/tasmee/domain/speech_activity_detector.dart';

Int16List _frame(int samples, int value) =>
    Int16List.fromList(List.filled(samples, value));

void main() {
  late SpeechActivityDetector detector;

  setUp(() {
    detector = SpeechActivityDetector(
      sampleRate: 1000,
      frameMilliseconds: 20,
      threshold: 0.01,
      preRollMilliseconds: 60,
      endSilenceMilliseconds: 60,
    );
  });

  test('buffers only a bounded pre-roll while idle', () {
    expect(detector.addFrame(_frame(20, 0)).audio, isEmpty);
    expect(detector.addFrame(_frame(20, 0)).audio, isEmpty);
    final voice = detector.addFrame(_frame(20, 2000));
    expect(voice.audio, hasLength(3));
    expect(voice.audio.last.first, 2000);
    expect(detector.inSpeech, isTrue);
  });

  test('ends speech after the configured quiet frames', () {
    detector.addFrame(_frame(20, 2000));
    expect(detector.addFrame(_frame(20, 0)).speechEnded, isFalse);
    expect(detector.addFrame(_frame(20, 0)).speechEnded, isFalse);
    final ended = detector.addFrame(_frame(20, 0));
    expect(ended.speechEnded, isTrue);
    expect(detector.inSpeech, isFalse);
  });

  test('returns every frame exactly once after speech begins', () {
    detector.addFrame(_frame(20, 0));
    final started = detector.addFrame(_frame(20, 2000));
    expect(started.audio.map((f) => f.first), [0, 2000]);
    final next = detector.addFrame(_frame(20, 2000));
    expect(next.audio.map((f) => f.first), [2000]);
  });

  test(
    'manual finish indicates whether speech was active and resets state',
    () {
      detector.addFrame(_frame(20, 2000));
      expect(detector.finish(), isTrue);
      expect(detector.inSpeech, isFalse);
      expect(detector.finish(), isFalse);
    },
  );

  test('rejects a frame with the wrong duration', () {
    expect(() => detector.addFrame(_frame(19, 1000)), throwsArgumentError);
  });

  group('adaptive thresholds', () {
    // 20 ms frames at 1 kHz; defaults otherwise (300 ms end silence).
    SpeechActivityDetector adaptive() =>
        SpeechActivityDetector(sampleRate: 1000, frameMilliseconds: 20);

    /// Feeds [seconds] of frames at [amplitude]; true if a segment ended.
    bool feed(SpeechActivityDetector d, double seconds, int amplitude) {
      var ended = false;
      for (var i = 0; i < (seconds * 50).round(); i++) {
        if (d.addFrame(_frame(20, amplitude)).speechEnded) ended = true;
      }
      return ended;
    }

    test('a breath between verses read aloud closes the segment', () {
      final d = adaptive();
      feed(d, 0.5, 20); // the room
      expect(feed(d, 3, 10000), isFalse); // loud recitation
      expect(d.inSpeech, isTrue);
      // A breath at about 1/20 of the voice: above the old fixed 0.012
      // threshold, but quiet next to this voice.
      expect(400 / 32768, greaterThan(0.012));
      expect(feed(d, 0.4, 400), isTrue);
    });

    test('a voice that softens briefly inside a word goes on', () {
      final d = adaptive();
      feed(d, 0.5, 20);
      expect(feed(d, 3, 10000), isFalse);
      expect(feed(d, 0.2, 400), isFalse); // a short stop consonant
      expect(feed(d, 2, 10000), isFalse);
      expect(d.inSpeech, isTrue);
    });

    test('steady room noise above the old threshold is not speech', () {
      final d = adaptive();
      // Noise at about 0.021 RMS: the old fixed threshold (0.012) took it
      // for speech and never closed a segment. Once half a second of it is
      // known, it is the floor.
      feed(d, 1, 700);
      expect(d.inSpeech, isFalse);
      expect(feed(d, 2, 700), isFalse);
      expect(d.inSpeech, isFalse);
      expect(d.silenceThreshold, greaterThan(700 / 32768));
      feed(d, 2, 8000);
      expect(d.inSpeech, isTrue);
      expect(feed(d, 0.5, 700), isTrue);
    });

    test('hysteresis: speech must clear the silence threshold to start', () {
      final d = adaptive();
      feed(d, 2, 700);
      expect(d.speechThreshold, greaterThan(d.silenceThreshold));
      final between = ((d.silenceThreshold + d.speechThreshold) / 2 * 32768)
          .round();
      expect(feed(d, 0.2, between), isFalse);
      expect(d.inSpeech, isFalse);
    });

    test('a silent room keeps the absolute minimum thresholds', () {
      final d = adaptive();
      feed(d, 2, 0);
      expect(d.silenceThreshold, d.minSilence);
      expect(d.speechThreshold, d.threshold);
    });
  });
}
