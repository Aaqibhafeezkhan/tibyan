import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'timing_updates.dart';

part 'word_timing_specs.dart';

/// Where the word-timing packs are served (tools/build_lean_content.py).
const wordTimingBaseUrl = 'https://tibyan.ahmedhelal.dev/mirror/packs/timing/';

/// One reciter's word-timing pack: a [TimingPack] file named by its SHA-256.
@immutable
class WordTimingSpec {
  const WordTimingSpec({
    required this.file,
    required this.sha256,
    required this.bytes,
  });

  final String file;
  final String sha256;
  final int bytes;
}

/// Word timings that are not inside the app: one small pack per reciter
/// ([wordTimingSpecs]), fetched with that reciter's audio or the first
/// time the reciter is heard, and kept under [dir] as `<reciter>.json.gz`.
///
/// Without its pack a recitation plays as before, with its verses marked
/// but not its words.
class WordTimingPacks {
  WordTimingPacks(
    this.dir, {
    this.specs = wordTimingSpecs,
    this.client,
    Uri? base,
  }) : _base = base ?? Uri.parse(wordTimingBaseUrl);

  final Directory dir;
  final Map<int, WordTimingSpec> specs;

  /// The HTTP client to use; a fresh one per download when null.
  final http.Client? client;
  final Uri _base;

  final _loaded = <int, Future<TimingPack?>>{};
  final _fetching = <int, Future<bool>>{};

  File file(int reciter) => File(p.join(dir.path, '$reciter.json.gz'));

  /// Whether [reciter]'s words come from a pack (else from content.db).
  bool packed(int reciter) => specs.containsKey(reciter);

  /// Whether [reciter]'s pack is on the device.
  bool has(int reciter) => file(reciter).existsSync();

  /// [reciter]'s pack if it is on the device and intact, else null.
  Future<TimingPack?> pack(int reciter) async {
    final spec = specs[reciter];
    if (spec == null) return null;
    final loaded = _loaded[reciter];
    if (loaded != null) {
      final pack = await loaded;
      if (pack != null) return pack;
    }
    if (!has(reciter)) return null;
    return _loaded[reciter] = _read(file(reciter), spec);
  }

  static Future<TimingPack?> _read(File file, WordTimingSpec spec) async {
    try {
      return await Isolate.run(() {
        final bytes = file.readAsBytesSync();
        if (sha256.convert(bytes).toString() != spec.sha256) {
          file.deleteSync();
          return null;
        }
        return TimingPack.decode(bytes);
      });
    } on Object {
      return null;
    }
  }

  /// Fetches [reciter]'s pack unless it is here already. Returns whether it
  /// is on the device afterwards. Never throws; offline it is tried again
  /// the next time.
  Future<bool> ensure(int reciter) {
    if (!packed(reciter)) return Future.value(false);
    if (has(reciter)) return Future.value(true);
    return _fetching[reciter] ??= _fetch(reciter).whenComplete(() {
      // A block, not an arrow: the removed future must not be awaited.
      _fetching.remove(reciter);
    });
  }

  Future<bool> _fetch(int reciter) async {
    final spec = specs[reciter]!;
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(_base.resolve(spec.file))
          .timeout(const Duration(seconds: 60));
      final bytes = r.bodyBytes;
      if (r.statusCode != 200 || bytes.length != spec.bytes) return false;
      if (sha256.convert(bytes).toString() != spec.sha256) return false;
      final pack = await Isolate.run(() => TimingPack.decode(bytes));
      if (pack.reciterId != reciter) return false;
      dir.createSync(recursive: true);
      final tmp = File('${file(reciter).path}.part')..writeAsBytesSync(bytes);
      tmp.renameSync(file(reciter).path);
      _loaded[reciter] = Future.value(pack);
      return true;
    } on Object {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Fetches the packs of [reciters] one after another (those whose audio
  /// is already on the device, after an update moved their words here).
  Future<void> ensureAll(Iterable<int> reciters) async {
    for (final r in reciters) {
      await ensure(r);
    }
  }
}
