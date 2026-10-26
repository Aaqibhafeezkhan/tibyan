import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;

import '../../core/db/habit_tables.dart' show newUuid;
import '../../core/settings/settings_controller.dart';
import '../../core/sync/cloud/cloud_store.dart';
import '../../core/sync/cloud/cloud_sync_engine.dart';
import '../../core/sync/cloud/google_drive_store.dart';
import '../../core/sync/cloud/icloud_store.dart';
import '../../core/sync/cloud/sync_records.dart';
import '../khatma/khatma_providers.dart';
import '../mushaf/mushaf_providers.dart';

/// The reader's own cloud on this platform: iCloud on Apple devices,
/// Google Drive on Android; none elsewhere.
final cloudStoreProvider = Provider<CloudStore?>((ref) {
  if (kIsWeb) return null;
  if (Platform.isIOS || Platform.isMacOS) return ICloudStore();
  if (Platform.isAndroid) return GoogleDriveStore.withGoogleSignIn();
  return null;
});

enum SyncPhase { idle, syncing, failed }

class CloudSyncState {
  const CloudSyncState({
    required this.enabled,
    this.kind,
    this.unavailable,
    this.phase = SyncPhase.idle,
    this.lastSync,
  });

  /// The reader switched sync on.
  final bool enabled;

  /// `icloud` or `gdrive`; null where there is no store.
  final String? kind;

  /// Why sync cannot run now; null when it can (or before the first check).
  final CloudUnavailable? unavailable;
  final SyncPhase phase;
  final DateTime? lastSync;

  CloudSyncState copyWith({
    bool? enabled,
    CloudUnavailable? Function()? unavailable,
    SyncPhase? phase,
    DateTime? lastSync,
  }) => CloudSyncState(
    enabled: enabled ?? this.enabled,
    kind: kind,
    unavailable: unavailable == null ? this.unavailable : unavailable(),
    phase: phase ?? this.phase,
    lastSync: lastSync ?? this.lastSync,
  );
}

final cloudSyncProvider = NotifierProvider<CloudSyncController, CloudSyncState>(
  CloudSyncController.new,
);

/// «المزامنة»: off until the reader switches it on. Then it syncs at start,
/// when the app comes back, a little after a change, and on «زامن الآن».
/// It never blocks the screen: a failed sync is tried again next time.
class CloudSyncController extends Notifier<CloudSyncState> {
  static const enabledKey = 'sync.cloud.enabled';
  static const lastSyncKey = 'sync.cloud.lastSync';
  static const deviceIdKey = 'sync.deviceId';

  /// How long after a change the sync waits for more changes.
  static const debounce = Duration(seconds: 20);

  Timer? _timer;
  Future<void>? _running;
  bool _applying = false;

  CloudStore? get _store => ref.read(cloudStoreProvider);

  @override
  CloudSyncState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final store = ref.watch(cloudStoreProvider);
    final last = prefs.getInt(lastSyncKey);
    final enabled = store != null && (prefs.getBool(enabledKey) ?? false);

    final lifecycle = AppLifecycleListener(onResume: _soon);
    final db = ref.read(userDatabaseProvider);
    final changes = db
        .tableUpdates(
          TableUpdateQuery.allOf([
            for (final t in db.allTables)
              if (syncedEntities.containsKey(t.actualTableName))
                TableUpdateQuery.onTable(t),
          ]),
        )
        .listen((_) => _changed());
    ref.listen(settingsProvider, (_, _) => _changed());
    ref.onDispose(() {
      lifecycle.dispose();
      unawaited(changes.cancel());
      _timer?.cancel();
    });
    if (enabled) Future.microtask(_soon);
    return CloudSyncState(
      enabled: enabled,
      kind: store?.kind,
      lastSync: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
    );
  }

  void _changed() {
    if (!state.enabled || _applying) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  void _soon() {
    if (state.enabled) unawaited(syncNow());
  }

  /// Checks the store without syncing (for the screen).
  Future<void> refresh() async {
    final store = _store;
    if (store == null) {
      state = state.copyWith(unavailable: () => CloudUnavailable.unsupported);
      return;
    }
    final why = await store.unavailable();
    state = state.copyWith(unavailable: () => why);
  }

  String _deviceId() {
    final prefs = ref.read(sharedPreferencesProvider);
    final have = prefs.getString(deviceIdKey);
    if (have != null) return have;
    final id = newUuid();
    unawaited(prefs.setString(deviceIdKey, id));
    return id;
  }

  CloudSyncEngine _engine(CloudStore store) => CloudSyncEngine(
    db: ref.read(userDatabaseProvider),
    prefs: SharedSyncPrefs(ref.read(sharedPreferencesProvider)),
    store: store,
    deviceId: _deviceId(),
  );

  /// Switches sync on, asking the reader to sign in when the store needs
  /// it. Returns whether it is on.
  Future<bool> enable() async {
    final store = _store;
    if (store == null) return false;
    final ok = await store.connect().catchError((Object e) {
      debugPrint('sync connect: $e');
      return false;
    });
    if (!ok) {
      await refresh();
      return false;
    }
    await ref.read(sharedPreferencesProvider).setBool(enabledKey, true);
    state = state.copyWith(enabled: true, unavailable: () => null);
    unawaited(syncNow());
    return true;
  }

  /// Stops syncing; what is in the cloud stays there.
  Future<void> disable() async {
    _timer?.cancel();
    await ref.read(sharedPreferencesProvider).setBool(enabledKey, false);
    state = state.copyWith(enabled: false, phase: SyncPhase.idle);
  }

  /// «إيقاف المزامنة وحذف بيانات السحابة»: stops syncing and deletes every
  /// device's sync file from the reader's cloud. What is on this device
  /// stays. Throws when the cloud cannot be reached (nothing is turned off
  /// then).
  Future<void> disableAndDeleteCloud() async {
    final store = _store;
    if (store == null) return;
    await _running;
    await store.deleteAll();
    await _engine(store).forget();
    await disable();
    await store.disconnect();
  }

  /// Syncs now unless a sync is running (then waits for it).
  Future<void> syncNow() {
    final running = _running;
    if (running != null) return running;
    final f = _syncOnce().whenComplete(() => _running = null);
    return _running = f;
  }

  Future<void> _syncOnce() async {
    final store = _store;
    if (store == null || !state.enabled) return;
    _timer?.cancel();
    final why = await store.unavailable();
    if (why != null) {
      state = state.copyWith(unavailable: () => why, phase: SyncPhase.failed);
      return;
    }
    state = state.copyWith(unavailable: () => null, phase: SyncPhase.syncing);
    try {
      _applying = true;
      final report = await _engine(store).sync();
      await _afterApply(report.changedEntities);
      final now = DateTime.now();
      await ref
          .read(sharedPreferencesProvider)
          .setInt(lastSyncKey, now.millisecondsSinceEpoch);
      state = state.copyWith(phase: SyncPhase.idle, lastSync: now);
    } on Object catch (e) {
      debugPrint('sync: $e');
      state = state.copyWith(phase: SyncPhase.failed);
    } finally {
      // Writes made by the sync itself are not changes to sync again.
      Future.delayed(const Duration(milliseconds: 50), () => _applying = false);
    }
  }

  /// What shows the synced records is worked out again, without a restart.
  Future<void> _afterApply(Set<String> changed) async {
    if (changed.contains(prefEntity)) {
      ref.invalidate(settingsProvider);
    }
    if (changed.any(
      (e) =>
          khatmaEntities.contains(e) ||
          e == 'srs_item' ||
          e == 'memorization' ||
          e == 'hifz_goal' ||
          e.startsWith('recitation_'),
    )) {
      try {
        await ref.read(khatmaServiceProvider).afterRestore();
      } on Object catch (e) {
        debugPrint('after sync: $e');
      }
    }
  }
}
