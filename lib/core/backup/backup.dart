import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/user_database.dart';
import '../sync/outbox_writer.dart';

/// A backup of what the reader made in the app, as one JSON file they keep:
/// fawasil and marks, the reading position, khatmas and their logs, reading
/// and listening reports, tadabbur notes, hifz progress, the recitation
/// record (results only), hifz goals, and the misbaha's own adhkar and
/// daily log. It needs no
/// account and goes through the system's share sheet; restoring it merges.
///
/// Rows are copied by SQL column name, so the file does not depend on the
/// Dart classes. The khatmas' caches (khatma_coverage, daily_stat) are not
/// part of it: they are rebuilt from the attributions after a restore. The
/// sync outbox is not part of it either: a restored row of a
/// synced table is queued in it again, so it reaches the account once sync
/// is switched on.
///
/// With [prefs], the reader's settings (`settings.*`: style, edition,
/// reciter, speed, what shows under the verse…) and the choices listed in
/// [preferenceKeys] are saved too, and a restore puts them back as they
/// were in the file.
class Backup {
  Backup(this._db, {this.prefs});

  final UserDatabase _db;
  final SharedPreferences? prefs;

  static const settingsPrefix = 'settings.';

  /// The reader's own choices kept outside `settings.*`, saved and
  /// restored with them. Every other key stays on its device:
  /// `window.*` (this computer's window), `sync.lastPull` (this device's
  /// place in the account's changes), `reports.*` (reports waiting to be
  /// sent, with contact details), `widget.verseOfDay.written` and
  /// `pending_actions` (the home widgets' state), `tasmee.model*` (what
  /// the server last said about the recitation model), `search.history`
  /// (the searches typed, private and of the moment) and
  /// `khatma.wirdBannerDismissed` (one day's banner). The fasil, the
  /// bookmarks and the rest of the reader's record are in the database.
  static const preferenceKeys = {
    'app.whatsNewSeen',
    'habits.streakNotes',
    'search.mode',
    'tasmee.autoUpdateModel',
    'tasmee.firstUseSeen',
    'tasmee.last',
    'tasmee.mode',
    'tasmee.onError',
    'tasmee.strictness',
    'tasmee.toastSeconds',
    'tasmee.vibration',
  };

  /// Whether a backup carries the preference [key].
  static bool carries(String key) =>
      key.startsWith(settingsPrefix) || preferenceKeys.contains(key);

  static const app = 'tibyan';
  static const format = 1;

  /// The tables saved, by SQL name.
  static const tables = [
    'bookmark_sets',
    'reading_positions',
    'khatma',
    'khatma_log',
    'khatma_pause',
    'reading_session',
    'session_attribution',
    'listening_session',
    'reflection',
    'srs_item',
    'memorization',
    'recitation_session',
    'recitation_verse',
    'recitation_word',
    'hifz_goal',
    'tasbih_dhikr',
    'tasbih_day',
  ];

  /// The backup as JSON text.
  Future<String> export({DateTime? now}) async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      final rows = await _db.customSelect('SELECT * FROM "$t"').get();
      // A row's id is local to the device, except the single reading
      // position, where it is the row's identity.
      out[t] = [
        for (final r in rows)
          if (t == 'reading_positions')
            {...r.data}
          else
            {...r.data}..remove('id'),
      ];
    }
    final prefs = this.prefs;
    return const JsonEncoder.withIndent(' ').convert({
      'app': app,
      'format': format,
      'schema': _db.schemaVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'tables': out,
      if (prefs != null)
        'settings': {
          for (final k in prefs.getKeys())
            if (carries(k)) k: prefs.get(k),
        },
    });
  }

  /// Merges a backup's text into the database and says what it did.
  /// Throws [BackupException] when the text is not a Tibyan backup.
  Future<BackupResult> import(String text) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupException('not JSON');
    }
    if (decoded is! Map || decoded['app'] != app || decoded['tables'] is! Map) {
      throw const BackupException('not a Tibyan backup');
    }
    final fmt = decoded['format'];
    if (fmt is! int || fmt > format) {
      throw const BackupException('made by a newer version');
    }
    final data = decoded['tables'] as Map;
    var added = 0, updated = 0, kept = 0;
    await _db.transaction(() async {
      for (final t in tables) {
        final rows = data[t];
        if (rows is! List) continue;
        final columns = await _columns(t);
        for (final row in rows) {
          if (row is! Map) continue;
          final r = await _mergeRow(t, columns, Map<String, Object?>.from(row));
          switch (r) {
            case _Merge.added:
              added++;
            case _Merge.updated:
              updated++;
            case _Merge.kept:
              kept++;
          }
        }
      }
    });
    final settings = await _restoreSettings(decoded['settings']);
    return BackupResult(
      added: added,
      updated: updated,
      kept: kept,
      settings: settings,
    );
  }

  /// Puts the file's settings back; returns how many. Only the keys a
  /// backup carries ([carries]) of the types the app stores are taken, so
  /// a file made before [preferenceKeys] (settings only) restores as it
  /// did.
  Future<int> _restoreSettings(Object? saved) async {
    final prefs = this.prefs;
    if (prefs == null || saved is! Map) return 0;
    var n = 0;
    for (final MapEntry(:key, :value) in saved.entries) {
      if (key is! String || !carries(key)) continue;
      final ok = switch (value) {
        bool v => await prefs.setBool(key, v),
        int v => await prefs.setInt(key, v),
        double v => await prefs.setDouble(key, v),
        String v => await prefs.setString(key, v),
        List v when v.every((e) => e is String) => await prefs.setStringList(
          key,
          v.cast<String>(),
        ),
        _ => false,
      };
      if (ok) n++;
    }
    return n;
  }

  /// A table's columns: name -> (is `NOT NULL` without a default, is the key).
  Future<Map<String, ({bool required, bool key})>> _columns(String t) async {
    final info = await _db.customSelect('PRAGMA table_info("$t")').get();
    return {
      for (final c in info)
        c.read<String>('name'): (
          required: c.read<int>('notnull') == 1 && c.data['dflt_value'] == null,
          key: c.read<int>('pk') > 0,
        ),
    };
  }

  Future<_Merge> _mergeRow(
    String table,
    Map<String, ({bool required, bool key})> columns,
    Map<String, Object?> row,
  ) async {
    // Columns this version knows; the row's own id is never carried over,
    // except for the single reading-position row.
    final keepsId = table == 'reading_positions';
    final values = {
      for (final e in row.entries)
        if (columns.containsKey(e.key) &&
            (keepsId || e.key != 'id') &&
            (e.value == null || e.value is num || e.value is String))
          e.key: e.value,
    };
    // A row missing a value the table needs cannot be restored.
    for (final c in columns.entries) {
      final auto = c.value.key && c.key == 'id' && !keepsId;
      if (c.value.required && !auto && values[c.key] == null) {
        return _Merge.kept;
      }
    }
    final where = _identity(table, values);
    if (where == null) return _Merge.kept;

    final found = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE ${where.sql}',
          variables: where.args,
        )
        .getSingleOrNull();
    if (found == null) {
      await _insert(table, values);
      await _queue(table, where);
      return _Merge.added;
    }
    // The newer change wins (a tie keeps what is on the device).
    final theirs = values['updated_at'];
    final mine = found.data['updated_at'];
    if (theirs is num && mine is num && theirs > mine) {
      await _update(table, values, where);
      await _queue(table, where);
      return _Merge.updated;
    }
    return _Merge.kept;
  }

  /// How a backup row finds its twin on this device.
  _Where? _identity(String table, Map<String, Object?> v) {
    switch (table) {
      case 'reading_positions':
        return _Where('id = ?', [Variable.withInt(1)]);
      case 'bookmark_sets':
        // The four fixed marks are one each; a named fasil is the same by
        // name and place.
        if (v['kind'] is String) {
          return _Where('kind = ?', [
            Variable.withString(v['kind']! as String),
          ]);
        }
        if (v['name'] is! String || v['surah'] is! num || v['ayah'] is! num) {
          return null;
        }
        return _Where('kind IS NULL AND name = ? AND surah = ? AND ayah = ?', [
          Variable.withString(v['name']! as String),
          Variable.withInt((v['surah']! as num).toInt()),
          Variable.withInt((v['ayah']! as num).toInt()),
        ]);
      // A session's verses and slips are theirs by the session's uuid.
      case 'recitation_verse':
        if (v['session'] is! String || v['verse'] is! num) return null;
        return _Where('session = ? AND verse = ?', [
          Variable.withString(v['session']! as String),
          Variable.withInt((v['verse']! as num).toInt()),
        ]);
      case 'recitation_word':
        if (v['session'] is! String ||
            v['verse'] is! num ||
            v['word'] is! num) {
          return null;
        }
        return _Where('session = ? AND verse = ? AND word = ?', [
          Variable.withString(v['session']! as String),
          Variable.withInt((v['verse']! as num).toInt()),
          Variable.withInt((v['word']! as num).toInt()),
        ]);
      // One row a dhikr a day a device (older backups: this device's).
      case 'tasbih_day':
        if (v['day'] is! String || v['dhikr'] is! String) return null;
        final device = v['device'];
        return _Where('day = ? AND dhikr = ? AND device = ?', [
          Variable.withString(v['day']! as String),
          Variable.withString(v['dhikr']! as String),
          Variable.withString(device is String ? device : ''),
        ]);
      default:
        final uuid = v['uuid'];
        return uuid is String
            ? _Where('uuid = ?', [Variable.withString(uuid)])
            : null;
    }
  }

  /// A restored row of a synced table goes to the outbox, as the app's own
  /// writes do (lib/core/sync/outbox_writer.dart), in the same JSON.
  Future<void> _queue(String table, _Where where) async {
    if (!syncedTables.contains(table)) return;
    final info = _db.allTables
        .where((t) => t.actualTableName == table)
        .firstOrNull;
    if (info == null) return;
    final raw = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE ${where.sql}',
          variables: where.args,
        )
        .getSingleOrNull();
    if (raw == null) return;
    final row = await info.map(raw.data) as DataClass;
    final json = row.toJson();
    await enqueueChange(
      _db,
      table: table,
      uuid: json['uuid'] as String,
      row: json,
      deleted: json['deletedAt'] != null,
    );
  }

  Variable _variable(Object? v) => switch (v) {
    null => const Variable<Object>(null),
    int i => Variable.withInt(i),
    num n => Variable.withReal(n.toDouble()),
    _ => Variable.withString(v as String),
  };

  Future<void> _insert(String table, Map<String, Object?> values) async {
    final keys = values.keys.toList();
    await _db.customInsert(
      'INSERT OR REPLACE INTO "$table" (${keys.map((k) => '"$k"').join(', ')}) '
      'VALUES (${List.filled(keys.length, '?').join(', ')})',
      variables: [for (final k in keys) _variable(values[k])],
      updates: _updates,
    );
  }

  Future<void> _update(
    String table,
    Map<String, Object?> values,
    _Where where,
  ) async {
    final keys = [
      for (final k in values.keys)
        if (k != 'id' && k != 'uuid') k,
    ];
    if (keys.isEmpty) return;
    await _db.customUpdate(
      'UPDATE "$table" SET ${keys.map((k) => '"$k" = ?').join(', ')} '
      'WHERE ${where.sql}',
      variables: [for (final k in keys) _variable(values[k]), ...where.args],
      updates: _updates,
    );
  }

  Set<TableInfo> get _updates => _db.allTables.toSet();
}

enum _Merge { added, updated, kept }

class _Where {
  _Where(this.sql, this.args);
  final String sql;
  final List<Variable> args;
}

/// What a restore did: rows added, rows replaced by a newer copy, rows left
/// as they were on this device.
class BackupResult {
  const BackupResult({
    required this.added,
    required this.updated,
    required this.kept,
    this.settings = 0,
  });
  final int added;
  final int updated;
  final int kept;

  /// Settings put back from the file.
  final int settings;
}

class BackupException implements Exception {
  const BackupException(this.reason);
  final String reason;
  @override
  String toString() => 'BackupException: $reason';
}
