import 'dart:convert';

/// One synced record as a device's sync file holds it: its latest change
/// ([updatedAt], [deviceId]) and the row, or a tombstone ([deleted]).
class SyncEntry {
  const SyncEntry({
    required this.entity,
    required this.key,
    required this.updatedAt,
    required this.deviceId,
    this.deleted = false,
    this.row,
  });

  /// The record type: a table's SQL name, or `pref` for a setting.
  final String entity;

  /// The record's key within [entity], the same on every device.
  final String key;

  /// Milliseconds since the epoch.
  final int updatedAt;
  final String deviceId;
  final bool deleted;

  /// The row by column name, without its local id; null for a tombstone.
  final Map<String, Object?>? row;

  String get id => recordId(entity, key);

  Map<String, Object?> toJson() => {
    'e': entity,
    'k': key,
    't': updatedAt,
    'd': deviceId,
    if (deleted) 'x': true,
    if (!deleted) 'r': row,
  };

  /// Null when [j] is not an entry (a file from a newer app, or damaged).
  static SyncEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'], k = j['k'], t = j['t'], d = j['d'], r = j['r'];
    if (e is! String || k is! String || t is! int || d is! String) {
      return null;
    }
    final deleted = j['x'] == true;
    if (!deleted && r is! Map) return null;
    return SyncEntry(
      entity: e,
      key: k,
      updatedAt: t,
      deviceId: d,
      deleted: deleted,
      row: deleted ? null : Map<String, Object?>.from(r as Map),
    );
  }
}

String recordId(String entity, String key) => '$entity\u0000$key';

/// Last write wins: whether a change at ([t], [device]) is newer than one
/// at ([otherT], [otherDevice]). Equal times are settled by the device id,
/// so every device picks the same winner.
bool isNewer(int t, String device, int otherT, String otherDevice) =>
    t > otherT || (t == otherT && device.compareTo(otherDevice) > 0);

/// The newest entry of each record across [entries].
Map<String, SyncEntry> newestOf(Iterable<SyncEntry> entries) {
  final out = <String, SyncEntry>{};
  for (final e in entries) {
    final have = out[e.id];
    if (have == null ||
        isNewer(e.updatedAt, e.deviceId, have.updatedAt, have.deviceId)) {
      out[e.id] = e;
    }
  }
  return out;
}

/// A device's sync file.
class SyncFile {
  const SyncFile({
    required this.deviceId,
    required this.writtenAt,
    required this.entries,
  });

  static const app = 'tibyan-sync';
  static const format = 1;
  static const prefix = 'tibyan-sync-';

  /// The file name of [deviceId]'s file.
  static String nameFor(String deviceId) => '$prefix$deviceId.json';

  final String deviceId;
  final int writtenAt;
  final List<SyncEntry> entries;

  String encode() => jsonEncode({
    'app': app,
    'format': format,
    'device': deviceId,
    'writtenAt': writtenAt,
    'entries': [for (final e in entries) e.toJson()],
  });

  /// Null when [text] is not a sync file this version can read.
  static SyncFile? decode(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (j is! Map || j['app'] != app) return null;
    final f = j['format'];
    if (f is! int || f > format) return null;
    final list = j['entries'];
    if (list is! List) return null;
    return SyncFile(
      deviceId: j['device'] is String ? j['device'] as String : '',
      writtenAt: j['writtenAt'] is int ? j['writtenAt'] as int : 0,
      entries: [
        for (final e in list)
          if (SyncEntry.fromJson(e) case final SyncEntry s) s,
      ],
    );
  }
}
