import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android draws a notification's small icon from its alpha channel only:
/// a filled square or a full-colour launcher icon shows as a blank blob.
void main() {
  const res = 'android/app/src/main/res';

  test('ic_stat_tibyan is a white vector silhouette', () {
    final xml = File('$res/drawable/ic_stat_tibyan.xml').readAsStringSync();
    expect(xml, contains('<vector'));
    expect(xml, contains('android:fillColor="#FFFFFFFF"'));
    expect(xml, isNot(contains('<rect')));
    // No raster copies that would shadow the vector per density.
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$res/drawable-$d/ic_stat_tibyan.png').existsSync(), isFalse);
    }
  });

  test('every notification source points at ic_stat_tibyan', () {
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains("androidNotificationIcon: 'drawable/ic_stat_tibyan'"),
    );
    expect(
      File('lib/features/khatma/services/reminder_scheduler.dart')
          .readAsStringSync(),
      contains("AndroidInitializationSettings('ic_stat_tibyan')"),
    );
    final aliases = File('$res/values/notification_icons.xml')
        .readAsStringSync();
    for (final name in [
      'outline_file_download_24',
      'outline_download_done_24',
      'outline_error_outline_24',
      'outline_pause_24',
    ]) {
      expect(aliases, contains('name="$name">@drawable/ic_stat_tibyan'));
    }
  });
}
