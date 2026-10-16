import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/core/db/content_database.dart';

import '../testing/disk_bundle.dart';

void main() {
  late Directory dir;
  late File file;
  final manifest = jsonDecode(
    File('${ContentDatabase.partsDir}manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('content-db');
    file = File(p.join(dir.path, 'content.db'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('the bundled parts are content.db, byte for byte', () {
    final whole = File('assets/db/content.db').readAsBytesSync();
    expect(manifest['bytes'], whole.length);
    expect(manifest['sha256'], sha256.convert(whole).toString());
    final parts = [
      for (final name in manifest['parts'] as List)
        ...File('${ContentDatabase.partsDir}$name').readAsBytesSync(),
    ];
    expect(sha256.convert(parts).toString(), manifest['sha256']);
  });

  test('a new install copies the parts out, a few MB at a time', () async {
    final bundle = DiskBundle();
    expect(await ContentDatabase.installBundled(bundle, file), isTrue);
    expect(
      sha256.convert(file.readAsBytesSync()).toString(),
      manifest['sha256'],
    );
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    // Never the whole file in one piece: each load is one part.
    final parts = bundle.loaded.where((k) => k.endsWith('.bin')).toList();
    expect(parts, hasLength((manifest['parts'] as List).length));
    for (final k in parts) {
      expect(File(k).lengthSync(), lessThanOrEqualTo(4 * 1024 * 1024));
    }
  });

  test('the next launch leaves the copy alone', () async {
    await ContentDatabase.installBundled(DiskBundle(), file);
    final bundle = DiskBundle();
    expect(await ContentDatabase.installBundled(bundle, file), isFalse);
    expect(bundle.loaded.where((k) => k.endsWith('.bin')), isEmpty);
  });

  test('an older build\'s copy is replaced (stamped by build number, with '
      'its word timings)', () async {
    file.writeAsStringSync('old content.db');
    File('${file.path}.stamp').writeAsStringSync('b412');
    File('${file.path}-wal').writeAsStringSync('old journal');
    expect(await ContentDatabase.installBundled(DiskBundle(), file), isTrue);
    expect(file.lengthSync(), manifest['bytes']);
    expect(File('${file.path}-wal').existsSync(), isFalse);
    expect(
      File('${file.path}.stamp').readAsStringSync(),
      's${manifest['sha256']}',
    );
  });
}
