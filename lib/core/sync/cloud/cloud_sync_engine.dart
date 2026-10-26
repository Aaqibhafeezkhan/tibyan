import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/user_database.dart';
import 'cloud_store.dart';
import 'sync_merge.dart';
import 'sync_records.dart';

/// What one sync did.
class SyncReport {
  const SyncReport({
    required this.applied,
    required this.uploaded,
    required this.changedEntities,
  });

  /// Records changed on this device from other devices.
  final int applied;

  /// Whether this device's file was written.
  final bool uploaded;
  final Set<String> changedEntities;
}

/// «المزامنة» between the reader's devices through their own cloud store.
///
/// 1. The journal notes what changed here since the last sync: a new or
///    changed row takes its own time of change (or now), a row gone becomes
///    a tombstone.
/// 2. Every device's file is read; for each record the newest change wins
///    (last write wins, ties by device id), and a winning change from
///    elsewhere is written here.
/// 3. This device's whole state goes up as its own file, only when it
///    changed.
///
/// Running it again with nothing new changes nothing (idempotent), and a
/// sync that fails half way leaves the device consistent: the journal and
/// the rows change together.
class CloudSyncEngine {
  CloudSyncEngine({
    required this.db,
    required this.prefs,
    required this.store,
    required this.deviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       records = SyncRecords(db, prefs, deviceId: deviceId);

  final UserDatabase db;
  final SyncPrefs prefs;
  final CloudStore store;
  final String deviceId;
  final SyncRecords records;
  final DateTime Function() _clock;

  static const uploadedHashKey = 'sync.cloud.uploadedHash';

  /// When changes stamped too far ahead arrived, by change.
  static const arrivalsKey = 'sync.cloud.arrivals';

  Map<String, int> _arrivals() {
    final text = prefs.get(arrivalsKey);
    if (text is! String) return {};
    try {
      final j = jsonDecode(text);
      return j is Map
          ? {
              for (final MapEntry(:key, :value) in j.entries)
                if (key is String && value is int) key: value,
            }
          : {};
    } on FormatException {
      return {};
    }
  }

  /// A change stamped further ahead than this is from a wrong clock: it
  /// counts as made when it arrived (or, here, when it was noted).
  static const maxAhead = Duration(days: 1);

  static List<String> get entities => [...syncedEntities.keys, prefEntity];

  Future<SyncReport> sync() async {
    final remote = await store.readAll();
    final now = _clock().millisecondsSinceEpoch;
    final incoming = <SyncEntry>[];
    final before = _arrivals();
    final arrivals = <String, int>{};
    for (final MapEntry(:key, :value) in remote.entries) {
      if (!key.startsWith(SyncFile.prefix)) continue;
      final f = SyncFile.decode(value);
      if (f == null) continue;
      for (final e in f.entries) {
        // The misbaha's log from before it kept devices.
        if (e.entity == 'tasbih_day' && !e.key.contains('"device"')) continue;
        if (e.updatedAt > now + maxAhead.inMilliseconds) {
          // The same change keeps the time it first arrived.
          final k = '${e.id}\u0001${e.deviceId}\u0001${e.updatedAt}';
          final t = arrivals[k] = before[k] ?? now;
          incoming.add(e.at(t));
        } else {
          incoming.add(e);
        }
      }
    }
    await journalLocalChanges(
      cloudHasPrefs: incoming.any((e) => e.entity == prefEntity),
    );
    await prefs.set(arrivalsKey, jsonEncode(arrivals));
    final changed = await applyRemote(newestOf(incoming).values);
    final uploaded = await upload();
    return SyncReport(
      applied: changed.$1,
      uploaded: uploaded,
      changedEntities: changed.$2,
    );
  }

  Future<Map<String, SyncJournalRow>> _journal(String entity) async => {
    for (final j in await (db.select(
      db.syncJournal,
    )..where((t) => t.entity.equals(entity))).get())
      j.recordKey: j,
  };

  /// Step 1: notes this device's changes since the last sync.
  ///
  /// Settings never synced yet are the device's defaults more often than
  /// a choice: when the cloud already has settings ([cloudHasPrefs]), the
  /// first sync takes them.
  Future<void> journalLocalChanges({bool cloudHasPrefs = false}) async {
    final now = _clock().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final entity in entities) {
        final local = await records.read(entity);
        final journal = await _journal(entity);
        final firstPrefs =
            entity == prefEntity && cloudHasPrefs && journal.isEmpty;
        for (final MapEntry(:key, value: rec) in local.entries) {
          final j = journal[key];
          final hash = rec.hash;
          if (j != null && !j.deleted && j.hash == hash) continue;
          var t = rec.updatedAt ?? (firstPrefs ? 0 : now);
          if (t > now + maxAhead.inMilliseconds) t = now;
          if (j != null && t <= j.updatedAt) t = j.updatedAt + 1;
          await _note(entity, key, hash, t, deviceId, deleted: false);
        }
        for (final j in journal.values) {
          if (j.deleted || local.containsKey(j.recordKey)) continue;
          final t = now > j.updatedAt ? now : j.updatedAt + 1;
          await _note(entity, j.recordKey, null, t, deviceId, deleted: true);
        }
      }
    });
  }

  Future<void> _note(
    String entity,
    String key,
    String? hash,
    int t,
    String device, {
    required bool deleted,
  }) => db
      .into(db.syncJournal)
      .insertOnConflictUpdate(
        SyncJournalCompanion.insert(
          entity: entity,
          recordKey: key,
          hash: Value(hash),
          updatedAt: t,
          deviceId: device,
          deleted: Value(deleted),
        ),
      );

  /// Step 2: writes here the changes from elsewhere that are newer than
  /// what this device has. Returns how many, and of which entities.
  Future<(int, Set<String>)> applyRemote(Iterable<SyncEntry> newest) async {
    final byEntity = <String, List<SyncEntry>>{};
    for (final e in newest) {
      if (!entities.contains(e.entity)) continue;
      (byEntity[e.entity] ??= []).add(e);
    }
    var applied = 0;
    final changed = <String>{};
    await db.transaction(() async {
      for (final MapEntry(key: entity, value: list) in byEntity.entries) {
        final journal = await _journal(entity);
        final wrote = <SyncEntry>[];
        for (final e in list) {
          final j = journal[e.key];
          if (j != null &&
              !isNewer(e.updatedAt, e.deviceId, j.updatedAt, j.deviceId)) {
            continue;
          }
          if (e.deleted) {
            await records.remove(entity, e.key);
            await _note(
              entity,
              e.key,
              null,
              e.updatedAt,
              e.deviceId,
              deleted: true,
            );
            if (j != null && !j.deleted) {
              applied++;
              changed.add(entity);
            }
          } else if (await records.put(entity, e.key, e.row!)) {
            wrote.add(e);
          }
        }
        if (wrote.isEmpty) continue;
        // The hash of each row as it now is here, so the next sync does
        // not take it for a change of this device's.
        final local = await records.read(entity);
        for (final e in wrote) {
          final rec = local[e.key];
          final hash = rec?.hash;
          if (hash != null && hash == journal[e.key]?.hash) {
            // Already the same here: only the stamp moves.
          } else {
            applied++;
            changed.add(entity);
          }
          await _note(
            entity,
            e.key,
            hash,
            e.updatedAt,
            e.deviceId,
            deleted: rec == null,
          );
        }
      }
    });
    return (applied, changed);
  }

  /// Step 3: writes this device's file when its content changed.
  Future<bool> upload() async {
    final entries = <SyncEntry>[];
    for (final entity in entities) {
      final local = await records.read(entity);
      final journal = await _journal(entity);
      final keys = journal.keys.toList()..sort();
      for (final k in keys) {
        final j = journal[k]!;
        final rec = local[k];
        entries.add(
          SyncEntry(
            entity: entity,
            key: k,
            updatedAt: j.updatedAt,
            deviceId: j.deviceId,
            deleted: j.deleted || rec == null,
            row: j.deleted ? null : rec?.row,
          ),
        );
      }
    }
    final body = SyncFile(
      deviceId: deviceId,
      writtenAt: 0,
      entries: entries,
    ).encode();
    final hash = hashRow({'body': body});
    if (prefs.get(uploadedHashKey) == hash) return false;
    final file = SyncFile(
      deviceId: deviceId,
      writtenAt: _clock().millisecondsSinceEpoch,
      entries: entries,
    );
    await store.write(SyncFile.nameFor(deviceId), file.encode());
    await prefs.set(uploadedHashKey, hash);
    return true;
  }

  /// Forgets what was synced, so a later start begins afresh. The rows
  /// stay on the device.
  Future<void> forget() async {
    await db.delete(db.syncJournal).go();
    await prefs.remove(uploadedHashKey);
    await prefs.remove(arrivalsKey);
  }
}
