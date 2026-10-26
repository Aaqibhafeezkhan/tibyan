import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../db/user_database.dart';

/// The preferences sync reads and writes; [SharedSyncPrefs] in the app.
abstract interface class SyncPrefs {
  Object? get(String key);

  /// Stores [value] when it is of a type preferences keep; returns whether.
  Future<bool> set(String key, Object? value);
  Future<void> remove(String key);
}

class SharedSyncPrefs implements SyncPrefs {
  SharedSyncPrefs(this.prefs);
  final SharedPreferences prefs;

  @override
  Object? get(String key) => prefs.get(key);

  @override
  Future<bool> set(String key, Object? value) => switch (value) {
    bool v => prefs.setBool(key, v),
    int v => prefs.setInt(key, v),
    double v => prefs.setDouble(key, v),
    String v => prefs.setString(key, v),
    List v when v.every((e) => e is String) => prefs.setStringList(
      key,
      v.cast<String>(),
    ),
    _ => Future.value(false),
  };

  @override
  Future<void> remove(String key) => prefs.remove(key);
}

/// Preferences in a map, for tests.
class MapSyncPrefs implements SyncPrefs {
  final values = <String, Object?>{};

  @override
  Object? get(String key) => values[key];

  @override
  Future<bool> set(String key, Object? value) async {
    if (value == null) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// A synced record as it is on this device.
class LocalRecord {
  const LocalRecord(this.row, this.updatedAt);

  /// By column name, without the local id.
  final Map<String, Object?> row;

  /// The row's own time of change in milliseconds, when it keeps one.
  final int? updatedAt;

  String get hash => hashRow(row);
}

/// A stable hash of a row, whatever the order of its columns.
String hashRow(Map<String, Object?> row) {
  final keys = row.keys.toList()..sort();
  final text = jsonEncode([
    for (final k in keys) [k, row[k]],
  ]);
  return sha1.convert(utf8.encode(text)).toString();
}

/// The tables that sync, by SQL name, and what makes a row the same
/// record on every device.
///
/// What syncs («المزامنة»): the fawasil and fixed marks, the khatmas with
/// their record (sessions, attributions, pauses, the old log), the hifz
/// (spaced review, memorization strength — the memorize mode's self-checks
/// land there —, goals and the recitation record) and the misbaha (the
/// reader's own adhkar and the daily log). The khatmas' caches
/// (khatma_coverage, daily_stat) are rebuilt from the record instead.
const syncedEntities = <String, List<String>>{
  'bookmark_sets': ['uuid'],
  'khatma': ['uuid'],
  'khatma_log': ['uuid'],
  'khatma_pause': ['uuid'],
  'reading_session': ['uuid'],
  'listening_session': ['uuid'],
  'session_attribution': ['uuid'],
  'srs_item': ['uuid'],
  'memorization': ['uuid'],
  'hifz_goal': ['uuid'],
  'recitation_session': ['uuid'],
  'recitation_verse': ['session', 'verse'],
  'recitation_word': ['session', 'verse', 'word'],
  'tasbih_dhikr': ['uuid'],
  'tasbih_day': ['day', 'dhikr'],
};

/// The entity of synced settings.
const prefEntity = 'pref';

/// The settings that sync: how the mushaf looks and turns, and the
/// reciter. What belongs to one device stays there: the edition (its pack
/// may not be downloaded elsewhere), the language, downloads, the window,
/// the screen, reminders and notifications.
const syncedPrefs = {
  'settings.style',
  'settings.interfaceStyle',
  'settings.mode',
  'settings.uiFont',
  'settings.pageTurn',
  'settings.pageFill',
  'settings.markerStyle',
  'settings.markerTint',
  'settings.reciterId',
  'settings.fasilStyle',
  'settings.fasilPlace',
  'settings.fasilMaterial',
  'settings.fasilTassel',
};

/// The khatma tables: a change in one of them means the khatmas' caches
/// must be rebuilt.
const khatmaEntities = {
  'khatma',
  'khatma_log',
  'khatma_pause',
  'reading_session',
  'listening_session',
  'session_attribution',
};

/// Reads and writes synced records on this device.
class SyncRecords {
  SyncRecords(this.db, this.prefs);

  final UserDatabase db;
  final SyncPrefs prefs;

  /// The key columns of [entity]'s [row]: the four fixed marks are one
  /// record each by their kind on every device.
  static List<String> keyColumns(String entity, Map<String, Object?> row) {
    if (entity == 'bookmark_sets' && row['kind'] is String) return ['kind'];
    return syncedEntities[entity]!;
  }

  /// The record key of [row], or null when a key column is empty.
  static String? keyOf(String entity, Map<String, Object?> row) {
    final cols = keyColumns(entity, row);
    final parts = <List<Object?>>[];
    for (final c in cols) {
      final v = row[c];
      if (v == null) return null;
      parts.add([c, v]);
    }
    return jsonEncode(parts);
  }

  /// Every record of [entity] on this device, by key.
  Future<Map<String, LocalRecord>> read(String entity) async {
    if (entity == prefEntity) {
      return {
        for (final k in syncedPrefs)
          if (prefs.get(k) case final Object v)
            k: LocalRecord({
              'value': v is List ? List<Object?>.of(v) : v,
            }, null),
      };
    }
    final rows = await db.customSelect('SELECT * FROM "$entity"').get();
    final out = <String, LocalRecord>{};
    for (final r in rows) {
      final row = {...r.data}..remove('id');
      final key = keyOf(entity, row);
      if (key == null) continue;
      final t = row['updated_at'];
      // drift keeps times in seconds.
      out[key] = LocalRecord(row, t is int ? t * 1000 : null);
    }
    return out;
  }

  /// Writes [row] as the record [key] of [entity]. Returns false when the
  /// row lacks a value this device's table needs (a file from another
  /// version), leaving the device as it was.
  Future<bool> put(String entity, String key, Map<String, Object?> row) async {
    if (entity == prefEntity) return _putPref(key, row['value']);
    final columns = await _columns(entity);
    final values = <String, Object?>{
      for (final e in row.entries)
        if (columns.containsKey(e.key) &&
            e.key != 'id' &&
            (e.value == null || e.value is num || e.value is String))
          e.key: e.value,
    };
    final where = _where(key);
    final found = await db
        .customSelect(
          'SELECT 1 FROM "$entity" WHERE ${where.sql}',
          variables: where.args,
        )
        .getSingleOrNull();
    if (found == null) {
      for (final c in columns.entries) {
        if (c.value && c.key != 'id' && values[c.key] == null) return false;
      }
      final keys = values.keys.toList();
      await db.customInsert(
        'INSERT INTO "$entity" (${keys.map((k) => '"$k"').join(', ')}) '
        'VALUES (${List.filled(keys.length, '?').join(', ')})',
        variables: [for (final k in keys) _variable(values[k])],
        updates: _tables(entity),
      );
      return true;
    }
    final keys = values.keys.toList();
    if (keys.isEmpty) return true;
    await db.customUpdate(
      'UPDATE "$entity" SET ${keys.map((k) => '"$k" = ?').join(', ')} '
      'WHERE ${where.sql}',
      variables: [for (final k in keys) _variable(values[k]), ...where.args],
      updates: _tables(entity),
    );
    return true;
  }

  /// Removes the record [key] of [entity], when it is here.
  Future<void> remove(String entity, String key) async {
    if (entity == prefEntity) {
      await prefs.remove(key);
      return;
    }
    final where = _where(key);
    await db.customUpdate(
      'DELETE FROM "$entity" WHERE ${where.sql}',
      variables: where.args,
      updates: _tables(entity),
      updateKind: UpdateKind.delete,
    );
  }

  Future<bool> _putPref(String key, Object? value) async =>
      syncedPrefs.contains(key) && await prefs.set(key, value);

  _Where _where(String key) {
    final parts = (jsonDecode(key) as List).cast<List>();
    return _Where(parts.map((p) => '"${p[0]}" = ?').join(' AND '), [
      for (final p in parts) _variable(p[1]),
    ]);
  }

  final _columnCache = <String, Map<String, bool>>{};

  /// A table's columns: name -> whether a row must give it a value.
  Future<Map<String, bool>> _columns(String t) async {
    final have = _columnCache[t];
    if (have != null) return have;
    final info = await db.customSelect('PRAGMA table_info("$t")').get();
    return _columnCache[t] = {
      for (final c in info)
        c.read<String>('name'):
            c.read<int>('notnull') == 1 && c.data['dflt_value'] == null,
    };
  }

  Set<TableInfo> _tables(String entity) =>
      db.allTables.where((t) => t.actualTableName == entity).toSet();

  Variable _variable(Object? v) => switch (v) {
    null => const Variable<Object>(null),
    int i => Variable.withInt(i),
    num n => Variable.withReal(n.toDouble()),
    _ => Variable.withString(v as String),
  };
}

class _Where {
  _Where(this.sql, this.args);
  final String sql;
  final List<Variable> args;
}
