import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A dhikr the misbaha counts: one of the app's adhkar (from a licensed
/// source, copied verbatim with its reference) or one the reader added.
@immutable
class Dhikr {
  const Dhikr({
    required this.key,
    required this.text,
    this.reference,
    this.target,
    this.mine = false,
  });

  /// `app:<id>` or `user:<uuid>`: what the daily log is kept under.
  final String key;
  final String text;
  final String? reference;

  /// The suggested count to a round.
  final int? target;

  /// Added by the reader («من إضافتك»).
  final bool mine;

  /// The uuid of the reader's own dhikr.
  String? get uuid => mine ? key.substring(5) : null;

  @override
  bool operator ==(Object other) =>
      other is Dhikr &&
      other.key == key &&
      other.text == text &&
      other.reference == reference &&
      other.target == target &&
      other.mine == mine;

  @override
  int get hashCode => Object.hash(key, text, reference, target, mine);
}

/// Where the app's adhkar come from (assets/tasbih/adhkar.json).
@immutable
class DhikrSource {
  const DhikrSource({
    required this.url,
    required this.commit,
    required this.license,
  });

  final String url;
  final String commit;
  final String license;
}

/// Reads `assets/tasbih/adhkar.json`.
({DhikrSource source, List<Dhikr> adhkar}) parseAppAdhkar(String json) {
  final m = jsonDecode(json) as Map<String, Object?>;
  return (
    source: DhikrSource(
      url: m['source']! as String,
      commit: m['commit']! as String,
      license: m['license']! as String,
    ),
    adhkar: [
      for (final e in (m['items']! as List).cast<Map<String, Object?>>())
        Dhikr(
          key: 'app:${e['id']}',
          text: e['text']! as String,
          reference: e['reference'] as String?,
          target: (e['count'] as num?)?.toInt(),
        ),
    ],
  );
}
