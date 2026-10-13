import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/content_database.dart';
import '../../core/downloads/background_downloads.dart';
import '../audio/background_recitations.dart';
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

/// Queued on the system's background downloader ([BackgroundRecitations]),
/// so it goes on when the reader leaves the app and shows in the
/// Downloads screen; this follows how many surahs are on the device.
class FullMushafAudioDownload extends Notifier<FullMushafAudio?> {
  int? _reciter;

  @override
  FullMushafAudio? build() {
    final bg = ref.watch(backgroundRecitationsProvider);
    final downloads = ref.watch(backgroundDownloadsProvider);
    void changed() => _refresh(bg);
    bg.files.changes.addListener(changed);
    downloads.tasks.addListener(changed);
    ref.onDispose(() {
      bg.files.changes.removeListener(changed);
      downloads.tasks.removeListener(changed);
    });
    return null;
  }

  void _refresh(BackgroundRecitations bg) {
    final id = _reciter;
    if (id == null || !ref.mounted) return;
    final done = bg.files.downloaded(id).length;
    var running = false;
    for (var s = 1; s <= 114 && !running; s++) {
      running = bg.queued(id, s);
    }
    state = FullMushafAudio(reciterId: id, done: done, running: running);
  }

  /// Queues [reciter]'s whole mushaf unless it is already queued.
  void start(ReciterRow reciter, {String? displayName}) {
    if (state?.running == true && state!.reciterId == reciter.id) return;
    _reciter = reciter.id;
    final bg = ref.read(backgroundRecitationsProvider);
    final hosts = ref.read(audioHostsProvider.notifier);
    state = FullMushafAudio(
      reciterId: reciter.id,
      done: bg.files.downloaded(reciter.id).length,
    );
    unawaited(
      bg
          .enqueueAll(
            reciter,
            urls: (s) => hosts.urls(reciter, s),
            displayName: displayName ?? reciter.nameAr,
          )
          .then((_) => _refresh(bg), onError: (_) => _refresh(bg)),
    );
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
