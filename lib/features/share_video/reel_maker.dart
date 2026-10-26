import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'reel_painter.dart';
import 'reel_timeline.dart';

/// The device's video encoder (`app.tibyan/video`: AVFoundation on Apple
/// devices, MediaCodec on Android).
abstract interface class ReelEncoder {
  Future<bool> available();
  Future<void> start(String path, int width, int height, int fps);
  Future<void> frame(Uint8List rgba, int repeat);

  /// Lays [audio]'s [cut] under the frames, faded in and out; returns the
  /// finished MP4's path.
  Future<String> finish({File? audio, AudioCut? cut});
  Future<void> cancel();
}

class ChannelReelEncoder implements ReelEncoder {
  const ChannelReelEncoder();
  static const _c = MethodChannel('app.tibyan/video');

  @override
  Future<bool> available() async {
    try {
      return await _c.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start(String path, int width, int height, int fps) =>
      _c.invokeMethod('start', {
        'path': path,
        'width': width,
        'height': height,
        'fps': fps,
      });

  @override
  Future<void> frame(Uint8List rgba, int repeat) =>
      _c.invokeMethod('frame', {'rgba': rgba, 'repeat': repeat});

  @override
  Future<String> finish({File? audio, AudioCut? cut}) async =>
      (await _c.invokeMethod<String>('finish', {
        if (audio != null && cut != null) ...{
          'audio': audio.path,
          'audioStart': cut.startMs / 1000,
          'audioEnd': cut.endMs / 1000,
          'audioOffset': cut.offset,
          'fadeIn': ReelTiming.fadeIn,
          'fadeOut': ReelTiming.fadeOut,
        },
      }))!;

  @override
  Future<void> cancel() => _c.invokeMethod('cancel');
}

/// Thrown when the reader cancels.
class ReelCancelled implements Exception {}

/// Makes the reel's MP4 at [path], [size] pixels: draws each distinct frame
/// once and lets the encoder repeat it. [onProgress] goes from 0 to 1 over
/// the frames; [cancelled] is asked between frames.
Future<String> makeReel({
  required ReelPainter painter,
  required ReelTimeline timeline,
  required ReelEncoder encoder,
  required String path,
  required Size size,
  File? audio,
  void Function(double)? onProgress,
  bool Function()? cancelled,
}) async {
  final w = size.width.round(), h = size.height.round();
  await encoder.start(path, w, h, ReelTiming.fps);
  try {
    final runs = frameRuns(timeline, pageStarts: painter.pageStarts);
    final total = timeline.frameCount;
    var done = 0;
    for (final (state, count) in runs) {
      if (cancelled?.call() ?? false) throw ReelCancelled();
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size, state);
      final pic = rec.endRecording();
      final img = await pic.toImage(w, h);
      pic.dispose();
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      await encoder.frame(data!.buffer.asUint8List(), count);
      done += count;
      onProgress?.call(done / total);
    }
    if (cancelled?.call() ?? false) throw ReelCancelled();
    return await encoder.finish(audio: audio, cut: timeline.audio);
  } catch (_) {
    await encoder.cancel();
    rethrow;
  }
}
