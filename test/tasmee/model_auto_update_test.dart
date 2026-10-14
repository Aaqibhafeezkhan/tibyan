import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/features/mushaf/presentation/source_names.dart';
import 'package:tibyan/features/tasmee/data/model_auto_updater.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/data/model_store.dart';

import 'tasmee_fakes.dart';

List<int> _body(String version) => utf8.encode('weights $version ' * 40);

ModelManifest _manifest(String version, {List<int>? body}) {
  final b = body ?? _body(version);
  return ModelManifest(
    id: 'test-model',
    version: version,
    license: 'CC-BY-4.0',
    engine: ModelEngine.sherpaNemoCtc,
    files: [
      ModelFileSpec(
        name: 'model.int8.onnx',
        url: Uri.parse('https://mirror.example/test-model/$version/model'),
        sha256: sha256.convert(_body(version)).toString(),
        bytes: b.length,
      ),
    ],
  );
}

void main() {
  late Directory tmp;
  late ModelStore store;
  late SharedPreferences prefs;
  late FakeWifiFetcher fetcher;
  ModelManifest? offer;
  var enabled = true;
  var switched = 0;

  Future<void> install(ModelManifest m) async {
    final dir = store.directoryFor(m)..createSync(recursive: true);
    File(p.join(dir.path, m.files.single.name))
        .writeAsBytesSync(_body(m.version));
    await store.markInstalled(m);
  }

  ModelAutoUpdater updater() => ModelAutoUpdater(
    prefs: prefs,
    store: () async => store,
    findUpdate: () async => offer,
    fetcher: fetcher,
    enabled: () => enabled,
    onSwitched: () => switched++,
  );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('auto_update');
    store = ModelStore(Directory(p.join(tmp.path, 'models')));
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fetcher = FakeWifiFetcher(
      bodies: {
        for (final v in ['1', '2'])
          'https://mirror.example/test-model/$v/model': _body(v),
      },
    );
    offer = null;
    enabled = true;
    switched = 0;
    await install(_manifest('1'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('on Wi‑Fi: fetched, checked, switched, old removed, noticed', () async {
    offer = _manifest('2');
    final u = updater();
    expect(await u.run(), '2');
    final now = await store.installed('test-model');
    expect(now!.manifest.version, '2');
    expect(store.directoryFor(_manifest('1')).existsSync(), isFalse);
    expect(switched, 1);
    expect(u.takeNotice(), '2');
    expect(u.takeNotice(), isNull, reason: 'the notice is shown once');
  });

  test('no Wi‑Fi: the old model stays, the next check retries', () async {
    offer = _manifest('2');
    fetcher.wifi = false;
    final u = updater();
    expect(await u.run(), isNull);
    expect((await store.installed('test-model'))!.manifest.version, '1');
    expect(u.takeNotice(), isNull);
    fetcher.wifi = true;
    expect(await u.run(), '2');
  });

  test('a file that fails its checksum is dropped, never installed', () async {
    offer = _manifest('2');
    fetcher = FakeWifiFetcher(
      bodies: {'https://mirror.example/test-model/2/model': _body('X')},
    );
    expect(await updater().run(), isNull);
    expect((await store.installed('test-model'))!.manifest.version, '1');
    final dir = store.directoryFor(_manifest('2'));
    expect(File(p.join(dir.path, 'model.int8.onnx')).existsSync(), isFalse);
    expect(
      File(p.join(dir.path, 'model.int8.onnx.wifi')).existsSync(),
      isFalse,
    );
  });

  test(
    'a file finished in the background is used, not fetched again',
    () async {
      offer = _manifest('2');
      final dir = store.directoryFor(offer!)..createSync(recursive: true);
      File(p.join(dir.path, 'model.int8.onnx.wifi'))
          .writeAsBytesSync(_body('2'));
      expect(await updater().run(), '2');
      expect(fetcher.fetches, 0);
    },
  );

  test('during a session the switch waits until it ends', () async {
    offer = _manifest('2');
    final u = updater()..sessionStarted();
    expect(await u.run(), isNull, reason: 'nothing starts mid-session');
    expect(fetcher.fetches, 0);
    await u.sessionEnded();
    expect(await u.run(), '2');

    // Ready before the session, switched only after it.
    offer = _manifest('3', body: _body('3'));
    fetcher = FakeWifiFetcher(
      bodies: {'https://mirror.example/test-model/3/model': _body('3')},
    );
    final v = updater();
    final running = v.run();
    v.sessionStarted();
    expect(await running, isNull);
    expect(v.ready?.version, '3');
    expect((await store.installed('test-model'))!.manifest.version, '2');
    await v.sessionEnded();
    expect((await store.installed('test-model'))!.manifest.version, '3');
    expect(v.takeNotice(), '3');
  });

  test('the setting off: nothing is fetched', () async {
    offer = _manifest('2');
    enabled = false;
    expect(await updater().run(), isNull);
    expect(fetcher.fetches, 0);
  });

  test('no update: nothing is fetched', () async {
    expect(await updater().run(), isNull);
    expect(fetcher.fetches, 0);
  });

  group('manifest credits', () {
    Map<String, dynamic> json() => {
      ..._manifest('2').toJson(),
      'credits': [
        {
          'ar': 'متطوعو تبيان',
          'en': 'Tibyan volunteers',
          'role': 'recitations',
          'url': 'https://train.altibyan.app',
        },
        {'en': 'Only English'},
        'not an object',
        {'role': 'no name'},
      ],
    };

    test('read leniently and kept through installed.json', () {
      final m = ModelManifest.fromJson(json());
      expect(m.credits.map((c) => c.name('ar')), [
        'متطوعو تبيان',
        'Only English',
      ]);
      expect(m.credits.first.role, 'recitations');
      final again = ModelManifest.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      );
      expect(again.credits.first.en, 'Tibyan volunteers');
    });

    test('a bad credits field never blocks the model', () {
      final m = ModelManifest.fromJson({
        ..._manifest('2').toJson(),
        'credits': 7,
      });
      expect(m.credits, isEmpty);
    });
  });

  group('About › Sources follows the installed model', () {
    test('no model: the static entry', () {
      final s = recitationModelSource(null, 'ar');
      expect(s.installed, isFalse);
      expect(s.version, '7f32349');
      expect(s.text.license, contains('CC BY 4.0'));
      expect(s.published, isNull);
    });

    test('the installed version, licence and attribution', () {
      final m = fakeManifest(version: '1');
      final s = recitationModelSource(m, 'en');
      expect(s.installed, isTrue);
      expect(s.version, '1');
      expect(s.text.license, contains('CC BY 4.0'));
      expect(s.published, m.attribution);
      expect(s.credits, isEmpty);
    });

    test('a trained version credits the volunteers, in both languages', () {
      final m = ModelManifest.fromJson({
        ...fakeManifest().toJson(),
        'version': '2',
        'attribution':
            'Arabic FastConformer by NVIDIA, CC BY 4.0; CTC branch '
            'fine-tuned on recitations by متطوعو تبيان / Tibyan volunteers.',
      });
      expect(recitationModelSource(m, 'ar').credits, ['متطوعو تبيان']);
      expect(recitationModelSource(m, 'en').credits, ['Tibyan volunteers']);
      expect(recitationModelSource(m, 'en').version, '2');
    });

    test('another licence is shown as the manifest gives it', () {
      final m = ModelManifest.fromJson({
        ...fakeManifest().toJson(),
        'license': 'Apache-2.0',
      });
      expect(recitationModelSource(m, 'ar').text.license, 'Apache-2.0');
    });
  });
}
