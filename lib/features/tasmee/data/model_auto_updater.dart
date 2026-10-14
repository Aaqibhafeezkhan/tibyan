import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/settings_controller.dart';
import 'model_manifest.dart';
import 'model_store.dart';
import 'model_update_checker.dart';
import 'tasmee_backend.dart';
import 'tasmee_settings.dart';

/// Fetches one file on Wi‑Fi only. True once [dest] holds the whole file;
/// false when it could not be had this time (no Wi‑Fi, a failure, or the
/// download is still running in the background): the next check retries.
abstract interface class WifiFileFetcher {
  Future<bool> fetch({
    required String taskId,
    required Uri url,
    required File dest,
  });
}

/// [WifiFileFetcher] on the system's background downloader: the task waits
/// for Wi‑Fi (`requiresWiFi`), survives the app going to the background,
/// and resumes a broken transfer (`allowPause`, retries) instead of
/// starting over. No notification: the update is quiet.
class BackgroundWifiFetcher implements WifiFileFetcher {
  BackgroundWifiFetcher([FileDownloader? downloader])
    : _dl = downloader ?? FileDownloader();

  final FileDownloader _dl;

  static const group = 'tasmee-model';

  @override
  Future<bool> fetch({
    required String taskId,
    required Uri url,
    required File dest,
  }) async {
    // Still running from an earlier check (perhaps an earlier run of the
    // app): leave it; its file is picked up by a later check.
    if (await _dl.taskForId(taskId) != null) return false;
    final support = await getApplicationSupportDirectory();
    final task = DownloadTask(
      taskId: taskId,
      url: url.toString(),
      filename: p.basename(dest.path),
      directory: p.relative(dest.parent.path, from: support.path),
      baseDirectory: BaseDirectory.applicationSupport,
      group: group,
      updates: Updates.status,
      requiresWiFi: true,
      allowPause: true,
      retries: 3,
    );
    final result = await _dl.download(task);
    return result.status == TaskStatus.complete;
  }
}

/// Keeps the recognition model current without asking, on Wi‑Fi.
///
/// When the daily check finds a newer version, its files are fetched into
/// that version's own folder next to the model in use, each one checked
/// against its size and SHA-256. Only when every file is in place is the
/// new version marked installed, which removes the old one: until then the
/// old model keeps working. A session in progress is never disturbed: the
/// switch waits until it ends. Any failure is silent; the next check
/// retries (files already complete are kept).
class ModelAutoUpdater {
  ModelAutoUpdater({
    required this.prefs,
    required this.store,
    required this.findUpdate,
    required this.fetcher,
    required this.enabled,
    this.onSwitched,
  });

  final SharedPreferences prefs;
  final Future<ModelStore> Function() store;

  /// The newer manifest, or null ([ModelUpdateChecker.check]).
  final Future<ModelManifest?> Function() findUpdate;
  final WifiFileFetcher fetcher;

  /// The reader's setting «update the model automatically on Wi‑Fi».
  final bool Function() enabled;
  final void Function()? onSwitched;

  /// The version switched to, kept until its notice has been shown once.
  static const kUpdatedNotice = 'tasmee.modelUpdatedNotice';

  int _sessions = 0;
  bool _running = false;
  ModelManifest? _ready;

  /// A session uses the model: nothing is switched until [sessionEnded].
  void sessionStarted() => _sessions++;

  Future<void> sessionEnded() async {
    if (_sessions > 0) _sessions--;
    final ready = _ready;
    if (_sessions == 0 && ready != null) await _switch(ready);
  }

  bool get inSession => _sessions > 0;

  /// The version a switch is waiting on (all files ready), or null.
  ModelManifest? get ready => _ready;

  /// Checks (at most daily, see [findUpdate]) and, on Wi‑Fi, fetches and
  /// installs a newer model. Returns the version switched to, if any.
  Future<String?> run() async {
    if (_running || inSession || !enabled()) return null;
    _running = true;
    try {
      final offer = await findUpdate();
      if (offer == null) return null;
      final s = await store();
      if (!await _stage(s, offer)) return null;
      _ready = offer;
      if (inSession || !enabled()) return null;
      return await _switch(offer);
    } catch (_) {
      // Offline, no space, a bad file: quietly try again next time.
      return null;
    } finally {
      _running = false;
    }
  }

  /// The version to announce once, then forgotten.
  String? takeNotice() {
    final v = prefs.getString(kUpdatedNotice);
    if (v != null) unawaited(prefs.remove(kUpdatedNotice));
    return v;
  }

  Future<bool> _stage(ModelStore s, ModelManifest m) async {
    final dir = s.directoryFor(m);
    await dir.create(recursive: true);
    for (final f in m.files) {
      final file = File(p.join(dir.path, f.name));
      if (await _matches(file, f)) continue;
      final tmp = File('${file.path}.wifi');
      // Finished in the background since the last check.
      final ok =
          await _matches(tmp, f) ||
          await fetcher.fetch(
            taskId: 'tasmee-model-${m.id}-${m.version}-${f.name}',
            url: f.url,
            dest: tmp,
          );
      if (!ok) return false;
      if (!await _matches(tmp, f)) {
        if (await tmp.exists()) await tmp.delete();
        return false;
      }
      await tmp.rename(file.path);
    }
    return true;
  }

  static Future<bool> _matches(File file, ModelFileSpec f) async {
    if (!await file.exists() || await file.length() != f.bytes) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == f.sha256;
  }

  Future<String?> _switch(ModelManifest m) async {
    _ready = null;
    final s = await store();
    if (await s.installedFor(m) == null) await s.markInstalled(m);
    await prefs.setString(kUpdatedNotice, m.version);
    onSwitched?.call();
    return m.version;
  }
}

/// The app's one [ModelAutoUpdater] (kept alive so a switch deferred by a
/// session is remembered).
final tasmeeModelAutoUpdaterProvider = Provider<ModelAutoUpdater>((ref) {
  final backend = ref.watch(tasmeeBackendProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ModelAutoUpdater(
    prefs: prefs,
    store: backend.modelStore,
    // The same daily check the offer shows (one manifest fetch for both).
    findUpdate: () => ref.read(tasmeeModelUpdateProvider.future),
    fetcher: backend.wifiFetcher(),
    enabled: () => ref.read(tasmeeSettingsProvider).autoUpdateModel,
    onSwitched: () => ref.invalidate(tasmeeModelUpdateProvider),
  );
});
