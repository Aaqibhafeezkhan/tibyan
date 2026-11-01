import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The key screens draw their metadata separators as stars ([MetaText]):
/// no middle dot is written into their source, and each renders through
/// MetaText. A dot next to Arabic-Indic digits reads as a zero («٨٤ · ٣٠٣»).
void main() {
  const screens = {
    'home continue card': 'lib/features/home/home_screen.dart',
    'mushaf banner':
        'lib/features/mushaf/presentation/widgets/illuminated_frame.dart',
    'mushaf art banner':
        'lib/features/mushaf/presentation/widgets/art_frame.dart',
    'player bar': 'lib/features/audio/player_bar.dart',
    'khatma cards': 'lib/features/khatma/presentation/khatma_screen.dart',
    'search results': 'lib/features/search/semantic/meaning_results.dart',
    'download rows':
        'lib/features/mushaf/presentation/background_downloads_list.dart',
    'storage sizes': 'lib/features/settings/storage_screen.dart',
    'index': 'lib/features/mushaf/presentation/index_screen.dart',
  };
  for (final MapEntry(key: name, value: path) in screens.entries) {
    test('$name renders separators as stars', () {
      final src = File(path).readAsStringSync();
      expect(src.contains('MetaText('), isTrue, reason: path);
      // Code-built separators use the token only through MetaText; no
      // other dot-like separators are left.
      for (final dot in ['•', '∙', '⋅', '・']) {
        expect(src.contains(dot), isFalse, reason: '$path has $dot');
      }
    });
  }

  test('plain-text platform strings carry no middle dot', () {
    for (final path in [
      'apple/TibyanActions/TibyanActions.swift',
      'android/app/src/main/kotlin/app/tibyan/tibyan/TasbihWidgetProvider.kt',
      'ios/Runner/AppDelegate.swift',
    ]) {
      expect(
        File(path).readAsStringSync().contains('·'),
        isFalse,
        reason: path,
      );
    }
  });
}
