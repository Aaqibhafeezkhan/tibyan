import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tibyan/features/audio/word_timing_packs.dart';

/// The word-timing packs as the app would have them once downloaded: the
/// files tools/build_lean_content.py wrote to data/word_timing_packs/,
/// copied under their on-device names into a temporary folder.
WordTimingPacks localWordTimingPacks() {
  final dir = Directory.systemTemp.createTempSync('word-timing');
  for (final MapEntry(:key, :value) in wordTimingSpecs.entries) {
    File(p.join('data', 'word_timing_packs', value.file))
        .copySync(p.join(dir.path, '$key.json.gz'));
  }
  return WordTimingPacks(dir);
}
