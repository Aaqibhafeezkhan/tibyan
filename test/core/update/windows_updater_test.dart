import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tibyan/core/update/windows_updater.dart';

const _url = '${windowsInstallerPrefix}Tibyan-Windows-Setup-v0.9.0.exe';

Map<String, Object?> _feed(List<int> bytes, {String version = '0.9.0'}) => {
  'version': version,
  'build': 50,
  'url': _url,
  'sha256': sha256.convert(bytes).toString(),
  'size': bytes.length,
};

void main() {
  group('version compare', () {
    UpdateFeed f(String v, int b) =>
        UpdateFeed(version: v, build: b, url: _url, sha256: 'a' * 64, size: 1);
    test('newer version, build ties', () {
      expect(isNewer(f('0.9.0', 1), '0.8.2', 47), isTrue);
      expect(isNewer(f('0.8.10', 1), '0.8.9', 99), isTrue);
      expect(isNewer(f('1.0.0', 0), '0.99.99', 0), isTrue);
      expect(isNewer(f('0.8.2', 48), '0.8.2', 47), isTrue);
      expect(isNewer(f('0.8.2', 47), '0.8.2', 47), isFalse);
      expect(isNewer(f('0.8.1', 99), '0.8.2', 47), isFalse);
      expect(isNewer(f('0.9.0', 1), 'garbage', 0), isFalse);
    });
    test('feed parsing rejects foreign hosts and bad hashes', () {
      final ok = _feed([1, 2, 3]);
      expect(UpdateFeed.tryParse(ok), isNotNull);
      expect(
        UpdateFeed.tryParse({...ok, 'url': 'https://evil.example/x.exe'}),
        isNull,
      );
      expect(UpdateFeed.tryParse({...ok, 'sha256': 'xyz'}), isNull);
      expect(UpdateFeed.tryParse({...ok, 'version': '1.0'}), isNull);
      expect(UpdateFeed.tryParse('nope'), isNull);
    });
  });

  group('sha256', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('tibyan_sha'));
    tearDown(() => dir.deleteSync(recursive: true));
    test('verifies a file', () async {
      final file = File('${dir.path}/a.bin')
        ..writeAsBytesSync(utf8.encode('tibyan'));
      final want = sha256.convert(utf8.encode('tibyan')).toString();
      expect(await verifySha256(file, want), isTrue);
      expect(await verifySha256(file, want.toUpperCase()), isTrue);
      expect(await verifySha256(file, 'b' * 64), isFalse);
    });
  });

  group('state machine', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('tibyan_upd'));
    tearDown(() => dir.deleteSync(recursive: true));

    WindowsUpdater make(
      Map<String, Object?> feed,
      List<int> bytes, {
      String current = '0.8.2',
      List<File>? launched,
    }) => WindowsUpdater(
      client: MockClient((req) async {
        if (req.url.toString() == windowsFeedUrl) {
          return http.Response(jsonEncode(feed), 200);
        }
        if (req.url.toString() == _url) return http.Response.bytes(bytes, 200);
        return http.Response('', 404);
      }),
      currentVersion: () async => (current, 47),
      downloadDir: dir,
      launch: (f) async => launched?.add(f),
    );

    test('up to date', () async {
      final bytes = [1, 2, 3];
      final u = make(_feed(bytes, version: '0.8.1'), bytes, current: '0.8.2');
      final seen = <Type>[];
      u.addListener(() => seen.add(u.value.runtimeType));
      await u.check();
      expect(seen, [UpdateChecking, UpdateUpToDate]);
    });

    test('downloads, verifies, then installs on confirm', () async {
      final bytes = List<int>.generate(5000, (i) => i % 251);
      final launched = <File>[];
      final u = make(_feed(bytes), bytes, launched: launched);
      final seen = <Type>[];
      u.addListener(() => seen.add(u.value.runtimeType));
      await u.check();
      expect(seen.first, UpdateChecking);
      expect(seen, contains(UpdateDownloading));
      final ready = u.value as UpdateReady;
      expect(ready.installer.readAsBytesSync(), bytes);
      expect(launched, isEmpty); // never installs without the reader
      await u.check(); // a ready update stays ready
      expect(u.value, same(ready));
      await u.install();
      expect(launched.single.path, ready.installer.path);
    });

    test('hash mismatch fails and leaves no file', () async {
      final bytes = [9, 9, 9];
      final u = make({..._feed(bytes), 'sha256': 'c' * 64}, bytes);
      await u.check();
      expect(u.value, isA<UpdateFailed>());
      expect(dir.listSync(), isEmpty);
    });

    test('feed error fails', () async {
      final u = WindowsUpdater(
        client: MockClient((_) async => http.Response('down', 503)),
        currentVersion: () async => ('0.8.2', 47),
        downloadDir: dir,
        launch: (_) async {},
      );
      await u.check();
      expect(u.value, isA<UpdateFailed>());
    });
  });
}
