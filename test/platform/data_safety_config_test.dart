import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the platforms back up: the reader's own data (the user database
/// and the settings), never what the app can copy or download again.
void main() {
  group('Android Auto Backup', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final legacy = File('android/app/src/main/res/xml/backup_rules.xml')
        .readAsStringSync();
    final modern = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    test('the manifest points at both rule files', () {
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    // drift_flutter keeps user.sqlite in getApplicationDocumentsDirectory,
    // app_flutter/ on Android (the "root" domain); everything else the app
    // writes is under getApplicationSupportDirectory, files/ ("file").
    for (final (name, xml) in [('API ≤30', legacy), ('API 31+', modern)]) {
      test('$name: user.sqlite and the settings only', () {
        expect(
          xml,
          contains('<include domain="root" path="app_flutter/user.sqlite" />'),
        );
        expect(xml, contains('<include domain="sharedpref" path="." />'));
        for (final heavy in [
          'content.db',
          'packs',
          'audio',
          'timing',
          'recitation_models',
        ]) {
          expect(xml, isNot(contains('path="$heavy')), reason: heavy);
        }
        expect(xml, isNot(contains('domain="file"')));
        expect(xml, isNot(contains('domain="database"')));
      });
    }

    test('cloud backup and device transfer carry the same rules', () {
      String part(String tag) =>
          RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(modern)![1]!;
      expect(part('cloud-backup'), part('device-transfer'));
    });
  });

  group('Apple', () {
    for (final os in ['ios', 'macos']) {
      test('$os: Application Support is kept out of backups', () {
        final delegate = File('$os/Runner/AppDelegate.swift')
            .readAsStringSync();
        expect(delegate, contains('BackupExclusion.apply()'));
        expect(delegate, contains('.applicationSupportDirectory'));
        expect(delegate, contains('isExcludedFromBackup = true'));
        // The user database is in Documents, which stays backed up.
        expect(delegate, isNot(contains('.documentDirectory')));
      });

      test('$os: the privacy manifest is in the Runner target', () {
        final privacy = File('$os/Runner/PrivacyInfo.xcprivacy')
            .readAsStringSync();
        expect(privacy, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
        expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
        expect(privacy, contains('CA92.1'));
        expect(privacy, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
        expect(privacy, contains('C617.1'));
        final project = File('$os/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        expect(
          project,
          contains(
            'PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile',
          ),
        );
        expect(
          RegExp(r'PrivacyInfo\.xcprivacy in Resources \*/,').hasMatch(project),
          isTrue,
        );
      });
    }
  });
}
