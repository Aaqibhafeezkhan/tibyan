import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tibyan/core/sync/cloud/cloud_store.dart';
import 'package:tibyan/core/sync/cloud/google_drive_store.dart';

/// A Drive app folder in memory, answering the REST calls the store makes.
class _FakeDrive {
  final files = <String, ({String name, String body})>{};
  var next = 0;
  final seen = <String>[];

  Future<http.Response> handle(http.Request r) async {
    seen.add('${r.method} ${r.url.path}');
    if (r.headers['Authorization'] != 'Bearer good') {
      return http.Response('{}', 401);
    }
    final path = r.url.path;
    if (r.method == 'GET' && path == '/drive/v3/files') {
      expect(r.url.queryParameters['spaces'], 'appDataFolder');
      return http.Response(
        jsonEncode({
          'files': [
            for (final e in files.entries) {'id': e.key, 'name': e.value.name},
          ],
        }),
        200,
      );
    }
    if (r.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final f = files[path.split('/').last]!;
      return http.Response.bytes(utf8.encode(f.body), 200);
    }
    if (r.method == 'POST' && path == '/upload/drive/v3/files') {
      final text = utf8.decode(r.bodyBytes);
      final parts = text.split('--tibyan-sync-boundary');
      final meta = jsonDecode(
        parts[1].split('\r\n\r\n')[1].trim(),
      ) as Map<String, dynamic>;
      expect(meta['parents'], ['appDataFolder']);
      final body = parts[2].split('\r\n\r\n')[1];
      files['id${next++}'] = (
        name: meta['name'] as String,
        body: body.substring(0, body.length - 2),
      );
      return http.Response('{}', 200);
    }
    if (r.method == 'PATCH' && path.startsWith('/upload/drive/v3/files/')) {
      final id = path.split('/').last;
      files[id] = (name: files[id]!.name, body: utf8.decode(r.bodyBytes));
      return http.Response('{}', 200);
    }
    if (r.method == 'DELETE') {
      files.remove(path.split('/').last);
      return http.Response('', 204);
    }
    return http.Response('?', 400);
  }
}

void main() {
  test('writes, replaces, reads and deletes files in the app folder', () async {
    final drive = _FakeDrive();
    final store = GoogleDriveStore(
      configured: true,
      token: ({required interactive}) async => 'good',
      client: MockClient(drive.handle),
    );
    expect(await store.unavailable(), isNull);
    await store.write('tibyan-sync-a.json', '{"v":1}');
    await store.write('tibyan-sync-a.json', '{"v":2}');
    await store.write('tibyan-sync-b.json', '{"عربي":true}');
    expect(drive.files, hasLength(2));
    expect(await store.readAll(), {
      'tibyan-sync-a.json': '{"v":2}',
      'tibyan-sync-b.json': '{"عربي":true}',
    });
    await store.deleteAll();
    expect(drive.files, isEmpty);
  });

  test('an expired token is dropped and the call made again once', () async {
    final drive = _FakeDrive();
    var token = 'stale';
    final forgotten = <String>[];
    final store = GoogleDriveStore(
      configured: true,
      token: ({required interactive}) async => token,
      forgetToken: (t) async {
        forgotten.add(t);
        token = 'good';
      },
      client: MockClient(drive.handle),
    );
    expect(await store.readAll(), isEmpty);
    expect(forgotten, ['stale']);
  });

  test('a build without the client id, or no account, says why', () async {
    final none = GoogleDriveStore(
      configured: false,
      token: ({required interactive}) async => 'good',
    );
    expect(await none.unavailable(), CloudUnavailable.notInThisBuild);
    expect(await none.connect(), isFalse);
    final signedOut = GoogleDriveStore(
      configured: true,
      token: ({required interactive}) async => interactive ? 'good' : null,
    );
    expect(await signedOut.unavailable(), CloudUnavailable.noAccount);
    expect(await signedOut.connect(), isTrue);
  });
}
