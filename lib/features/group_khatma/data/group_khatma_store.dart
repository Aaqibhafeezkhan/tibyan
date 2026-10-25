import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'group_khatma_api.dart';

/// A group khatma this device follows: the secrets it holds (organizer,
/// its own parts) and the last state seen, for offline viewing. Kept on
/// the device only.
class SavedGroupKhatma {
  const SavedGroupKhatma({
    required this.id,
    this.organizerSecret,
    this.partSecrets = const {},
    this.reminders = const {},
    this.cached,
    this.cachedAt,
  });

  factory SavedGroupKhatma.fromJson(Map<String, dynamic> j) => SavedGroupKhatma(
    id: j['id'] as String,
    organizerSecret: j['org'] as String?,
    partSecrets: {
      for (final e in (j['parts'] as Map? ?? const {}).entries)
        int.parse(e.key as String): e.value as String,
    },
    reminders: {
      for (final e in (j['rem'] as Map? ?? const {}).entries)
        int.parse(e.key as String): DateTime.parse(e.value as String),
    },
    cached: j['cache'] == null
        ? null
        : GroupKhatma.fromJson(j['cache'] as Map<String, dynamic>),
    cachedAt: DateTime.tryParse(j['at'] as String? ?? ''),
  );

  final String id;
  final String? organizerSecret;
  final Map<int, String> partSecrets;
  final Map<int, DateTime> reminders;
  final GroupKhatma? cached;
  final DateTime? cachedAt;

  bool get isOrganizer => organizerSecret != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (organizerSecret != null) 'org': organizerSecret,
    'parts': {for (final e in partSecrets.entries) '${e.key}': e.value},
    'rem': {
      for (final e in reminders.entries) '${e.key}': e.value.toIso8601String(),
    },
    if (cached != null) 'cache': cached!.raw,
    if (cachedAt != null) 'at': cachedAt!.toIso8601String(),
  };

  SavedGroupKhatma copyWith({
    Map<int, String>? partSecrets,
    Map<int, DateTime>? reminders,
    GroupKhatma? cached,
    DateTime? cachedAt,
  }) => SavedGroupKhatma(
    id: id,
    organizerSecret: organizerSecret,
    partSecrets: partSecrets ?? this.partSecrets,
    reminders: reminders ?? this.reminders,
    cached: cached ?? this.cached,
    cachedAt: cachedAt ?? this.cachedAt,
  );
}

class GroupKhatmaStore {
  GroupKhatmaStore(this._prefs);

  static const _key = 'group_khatmas_v1';
  final SharedPreferences _prefs;

  List<SavedGroupKhatma> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          SavedGroupKhatma.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  SavedGroupKhatma? get(String id) {
    for (final k in all()) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> put(SavedGroupKhatma k) async {
    final list = [
      for (final e in all())
        if (e.id != k.id) e,
    ];
    list.insert(0, k);
    await _prefs.setString(
      _key,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }

  Future<void> remove(String id) async {
    final list = [
      for (final e in all())
        if (e.id != id) e,
    ];
    await _prefs.setString(
      _key,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }
}
