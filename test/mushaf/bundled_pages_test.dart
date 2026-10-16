import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/features/mushaf/data/bundled_pack.dart';
import 'package:tibyan/features/mushaf/data/page_pack.dart';

import '../testing/disk_bundle.dart';

void main() {
  const spec = PagePackSpec.madina1441;
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('packs'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the bundled pages are the published pack\'s, unchanged', () {
    final dir = spec.assetDir!;
    final manifest = jsonDecode(
      File('${dir}manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final files = manifest['files'] as List;
    expect(files, hasLength(604));
    for (final f in files.cast<Map<String, dynamic>>()) {
      final bytes = File('$dir${f['file']}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), f['xz_sha256'], reason: '$f');
    }
  });

  test('a fresh install has the edition with nothing on disk', () async {
    final installer = PagePackInstaller(root: root, spec: spec);
    expect(installer.isInstalled, isTrue);
    expect(installer.dir.existsSync(), isFalse);
    final bundle = DiskBundle();
    final store = PageStore(
      installer.dir,
      assetDir: spec.assetDir,
      bundle: bundle,
    );
    for (final page in [1, 2, 604]) {
      expect(await store.svg(page), startsWith('<'), reason: 'page $page');
    }
    expect(bundle.loaded, [
      '${spec.assetDir}001.svg.xz',
      '${spec.assetDir}002.svg.xz',
      '${spec.assetDir}604.svg.xz',
    ]);
    expect(root.listSync(), isEmpty);
  });

  test('an update removes the copy an older build extracted', () async {
    final old = Directory(p.join(root.path, spec.id))..createSync();
    File(p.join(old.path, '001.svg.xz')).writeAsStringSync('old');
    File(p.join(old.path, '.installed')).writeAsStringSync('x');
    File(p.join(root.path, 'bundled-${spec.id}.zip')).writeAsStringSync('zip');
    final other = Directory(p.join(root.path, 'pages-warsh-v1'))..createSync();

    expect(await removeExtractedBundledPack(DiskBundle(), root), isTrue);
    expect(old.existsSync(), isFalse);
    expect(
      File(p.join(root.path, 'bundled-${spec.id}.zip')).existsSync(),
      isFalse,
    );
    expect(other.existsSync(), isTrue, reason: 'other packs stay');
    // The edition still reads, from the app.
    expect(PagePackInstaller(root: root, spec: spec).isInstalled, isTrue);
    expect(
      await PageStore(
        Directory(p.join(root.path, spec.id)),
        assetDir: spec.assetDir,
        bundle: DiskBundle(),
      ).svg(1),
      startsWith('<'),
    );
    // Nothing to do the next time.
    expect(await removeExtractedBundledPack(DiskBundle(), root), isFalse);
  });

  test('a downloaded edition is still read from disk', () {
    final old = PagePackInstaller(root: root, spec: PagePackSpec.madina1405);
    expect(old.isInstalled, isFalse);
  });
}
