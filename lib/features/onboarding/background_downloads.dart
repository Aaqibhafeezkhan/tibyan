import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/content_database.dart';
import '../audio/recitation.dart';
import '../tasmee/data/model_downloader.dart';
import '../tasmee/data/model_manifest.dart';
import '../tasmee/data/tasmee_backend.dart';
import '../tasmee/presentation/tasmee_settings_screen.dart'
    show tasmeeModelInfoProvider;

/// About how much one reciter's whole mushaf takes (114 surahs at the
/// hosts' usual 128 kb/s), shown before the download: an estimate.
const fullMushafAudioMb = 900;

/// The whole mushaf in one reciter's voice, surah by surah, through the
/// same files the player saves to. It runs on while the reader moves on.
class FullMushafAudio {
  const FullMushafAudio({
    required this.reciterId,
    required this.done,
    this.running = true,
  });

  final int reciterId;
  final int done;
  final bool running;
}

final fullMushafAudioProvider =
    NotifierProvider<FullMushafAudioDownload, FullMushafAudio?>(
      FullMushafAudioDownload.new,
    );

class FullMushafAudioDownload extends Notifier<FullMushafAudio?> {
  @override
  FullMushafAudio? build() => null;

  /// Starts [reciter]'s download unless it is already running.
  void start(ReciterRow reciter) {
    if (state?.running == true && state!.reciterId == reciter.id) return;
    unawaited(_run(reciter));
  }

  Future<void> _run(ReciterRow r) async {
    final files = ref.read(audioFilesProvider);
    var done = 0;
    for (var s = 1; s <= 114; s++) {
      if (files.has(r.id, s)) {
        done++;
        continue;
      }
      state = FullMushafAudio(reciterId: r.id, done: done);
      try {
        await files.download(
          r,
          s,
          client: ref.read(audioHttpClientProvider),
          urls: ref.read(audioHostsProvider.notifier).urls(r, s),
        );
        done++;
      } catch (_) {
        // A surah that fails is fetched again when it is played.
      }
      if (!ref.mounted) return;
    }
    state = FullMushafAudio(reciterId: r.id, done: done, running: false);
  }
}

/// The recognition model's manifest (its size), or null offline.
final tasmeeManifestProvider = FutureProvider.autoDispose<ModelManifest?>((
  ref,
) async {
  try {
    return await ref.watch(tasmeeBackendProvider).fetchManifest();
  } catch (_) {
    return null;
  }
});

/// The recognition model downloading in the background: its fraction
/// done, 1 when installed, or null before it starts. [failed] after an
/// error.
class TasmeeModelDownloadState {
  const TasmeeModelDownloadState(this.fraction, {this.failed = false});

  final double fraction;
  final bool failed;
  bool get done => fraction >= 1 && !failed;
}

final tasmeeModelDownloadProvider =
    NotifierProvider<TasmeeModelDownload, TasmeeModelDownloadState?>(
      TasmeeModelDownload.new,
    );

class TasmeeModelDownload extends Notifier<TasmeeModelDownloadState?> {
  @override
  TasmeeModelDownloadState? build() => null;

  void start(ModelManifest manifest) {
    final s = state;
    if (s != null && !s.failed) return;
    state = const TasmeeModelDownloadState(0);
    unawaited(_run(manifest));
  }

  Future<void> _run(ModelManifest manifest) async {
    try {
      await ref
          .read(tasmeeBackendProvider)
          .download(
            manifest,
            cancel: ModelDownloadCancel(),
            onProgress: (p) {
              if (ref.mounted) {
                state = TasmeeModelDownloadState(p.fraction.clamp(0, .99));
              }
            },
          );
      if (!ref.mounted) return;
      state = const TasmeeModelDownloadState(1);
      ref.invalidate(tasmeeModelInfoProvider);
    } catch (_) {
      if (ref.mounted) {
        state = TasmeeModelDownloadState(state?.fraction ?? 0, failed: true);
      }
    }
  }
}
