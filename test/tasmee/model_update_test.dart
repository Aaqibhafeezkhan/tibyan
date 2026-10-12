import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/features/tasmee/data/model_downloader.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/data/model_store.dart';
import 'package:tibyan/features/tasmee/data/model_update_checker.dart';

/// A fake mirror: one manifest and the files of each version, over HTTPS
/// URLs a [MockClient] answers. [online] false fails every request.
class _Mirror {
  _Mirror(this.version);

  String version;
  String engine = ModelEngine.sherpaNemoCtc;
  bool online = true;
  int manifestRequests = 0;

  /// Holds back a version's file until completed (to look at the store
  /// while the new version downloads).
  Future<void>? gate;

  static const id = 'test-model';
  static const manifestUrl = 'https://mirror.example/test-model/manifest.json';

  static List<int> body(String version) =>
      utf8.encode('weights of version $version ' * 50);

  ModelManifest manifest() => ModelManifest(
    id: id,
    version: version,
    license: 'CC-BY-4.0',
    engine: engine,
    files: [
      ModelFileSpec(
        name: 'model.int8.onnx',
        url: Uri.parse('https://mirror.example/test-model/$version/model'),
        sha256: sha256.convert(body(version)).toString(),
        bytes: body(version).length,
      ),
    ],
  );

  MockClient get client => MockClient((request) async {
    if (!online) throw const SocketException('offline');
    final url = request.url.toString();
    if (url == manifestUrl) {
      manifestRequests++;
      return http.Response(jsonEncode(manifest().toJson()), 200);
    }
    final m = RegExp(r'/test-model/([^/]+)/model$').firstMatch(url);
    if (m == null) return http.Response('', 404);
    await gate;
    return http.Response.bytes(body(m.group(1)!), 200);
  });
}

void main() {
  group('compareModelVersions', () {
    test('numbers compare as numbers, part by part', () {
      expect(compareModelVersions('2', '1'), greaterThan(0));
      expect(compareModelVersions('10', '9'), greaterThan(0));
      expect(compareModelVersions('1.10', '1.9'), greaterThan(0));
      expect(compareModelVersions('1.2', '1.2.1'), lessThan(0));
      expect(compareModelVersions('3', '3'), 0);
    });
  });

  group('ModelUpdateChecker', () {
    late Directory tmp;
    late ModelStore store;
    late _Mirror mirror;
    late ModelDownloader downloader;
    late SharedPreferences prefs;
    var now = DateTime(2026, 10, 12, 9);

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('model_update_test');
      store = ModelStore(Directory(p.join(tmp.path, 'models')));
      mirror = _Mirror('1');
      downloader = ModelDownloader(store: store, client: mirror.client);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 12, 9);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    ModelUpdateChecker checker() => ModelUpdateChecker(
      prefs: prefs,
      installedModel: () => store.installed(_Mirror.id),
      fetchManifest: () => downloader.fetchManifest(_Mirror.manifestUrl),
      now: () => now,
    );

    Future<void> install(String version) async {
      mirror.version = version;
      await downloader.download(mirror.manifest());
    }

    test('nothing to offer before a model is installed', () async {
      mirror.version = '2';
      expect(await checker().check(), isNull);
      expect(mirror.manifestRequests, 0);
    });

    test('the same version on the mirror is no update', () async {
      await install('1');
      expect(await checker().check(), isNull);
      expect(mirror.manifestRequests, 1);
    });

    test('a newer version is offered, with its size', () async {
      await install('1');
      mirror.version = '2';
      final offer = await checker().check();
      expect(offer?.version, '2');
      expect(offer?.totalBytes, _Mirror.body('2').length);
    });

    test('at most once a day; the offer stays between checks', () async {
      await install('1');
      mirror.version = '2';
      expect((await checker().check())?.version, '2');
      now = now.add(const Duration(hours: 20));
      expect((await checker().check())?.version, '2');
      expect(mirror.manifestRequests, 1);
      now = now.add(const Duration(hours: 5));
      mirror.version = '3';
      expect((await checker().check())?.version, '3');
      expect(mirror.manifestRequests, 2);
    });

    test(
      'offline: quietly nothing, and the next opening tries again',
      () async {
        await install('1');
        mirror
          ..online = false
          ..version = '2';
        expect(await checker().check(), isNull);
        mirror.online = true;
        expect((await checker().check())?.version, '2');
      },
    );

    test(
      'a model for an engine this build cannot run is not offered',
      () async {
        await install('1');
        mirror
          ..version = '2'
          ..engine = 'some-future-engine';
        expect(await checker().check(), isNull);
      },
    );

    test(
      'the old version works until the new one is complete, then goes',
      () async {
        await install('1');
        mirror.version = '2';
        final offer = (await checker().check())!;
        final release = Completer<void>();
        mirror.gate = release.future;
        final downloading = downloader.download(offer);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Mid-download: version 1 is still the model in use.
        expect((await store.installed(_Mirror.id))?.manifest.version, '1');
        release.complete();
        final installed = await downloading;
        expect(installed.manifest.version, '2');
        expect((await store.installed(_Mirror.id))?.manifest.version, '2');
        expect(
          Directory(p.join(store.root.path, _Mirror.id, '1')).existsSync(),
          isFalse,
        );
        // Installed: nothing more to offer.
        now = now.add(const Duration(days: 2));
        expect(await checker().check(), isNull);
      },
    );

    test('a newer version folder that is not complete is never used', () async {
      await install('9');
      // A version 10 that started downloading (no marker): 9 stays in use,
      // even though «10» sorts before «9» as text.
      Directory(p.join(store.root.path, _Mirror.id, '10'))
          .createSync(recursive: true);
      expect((await store.installed(_Mirror.id))?.manifest.version, '9');
    });
  });
}
