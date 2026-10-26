import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'cloud_store.dart';

/// The web OAuth client id of Tibyan's Google Cloud project, given at build
/// time (`--dart-define=TIBYAN_GOOGLE_SERVER_CLIENT_ID=…`, see
/// `docs/SYNC.md`). Empty in a build made without it: Google Drive sync is
/// then «not available in this version».
const googleServerClientId = String.fromEnvironment(
  'TIBYAN_GOOGLE_SERVER_CLIENT_ID',
);

/// Only the app's own hidden folder in the reader's Drive: Tibyan cannot
/// see any other file there.
const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

/// An access token for [driveAppDataScope]; with [interactive] the reader
/// may be asked to choose an account and allow it. Null when there is none.
typedef DriveToken = Future<String?> Function({required bool interactive});

/// The reader's Google Drive app folder (`appDataFolder`), through the
/// Drive REST API. Each device's file is one Drive file there.
class GoogleDriveStore implements CloudStore {
  GoogleDriveStore({
    required this.configured,
    required this.token,
    this.forgetToken,
    this.signOut,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// The app's real store, signing in with google_sign_in.
  factory GoogleDriveStore.withGoogleSignIn() {
    final auth = _GoogleAuth();
    return GoogleDriveStore(
      configured: googleServerClientId.isNotEmpty,
      token: auth.token,
      forgetToken: auth.forget,
      signOut: auth.signOut,
    );
  }

  /// Whether this build carries the OAuth client id.
  final bool configured;
  final DriveToken token;
  final Future<void> Function(String token)? forgetToken;
  final Future<void> Function()? signOut;
  final http.Client _client;

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  @override
  String get kind => 'gdrive';

  @override
  Future<CloudUnavailable?> unavailable() async {
    if (!configured) return CloudUnavailable.notInThisBuild;
    try {
      return await token(interactive: false) == null
          ? CloudUnavailable.noAccount
          : null;
    } on Object catch (e) {
      debugPrint('drive: $e');
      return CloudUnavailable.noAccount;
    }
  }

  @override
  Future<bool> connect() async {
    if (!configured) return false;
    return await token(interactive: true) != null;
  }

  /// Sends a request with the token, once more with a fresh one when the
  /// first was refused (tokens can expire before they say so).
  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final t = await token(interactive: false);
      if (t == null) throw const DriveException(401, 'not signed in');
      final req = http.Request(method, url)
        ..headers.addAll({'Authorization': 'Bearer $t', ...headers});
      if (body is String) req.body = body;
      if (body is List<int>) req.bodyBytes = body;
      final res = await http.Response.fromStream(await _client.send(req));
      if (res.statusCode == 401 && attempt == 0 && forgetToken != null) {
        await forgetToken!(t);
        continue;
      }
      if (res.statusCode >= 300) {
        throw DriveException(res.statusCode, res.body);
      }
      return res;
    }
  }

  /// The sync files: name -> Drive file id.
  Future<Map<String, String>> _list() async {
    final out = <String, String>{};
    String? page;
    do {
      final res = await _send(
        'GET',
        Uri.parse(_api).replace(
          queryParameters: {
            'spaces': 'appDataFolder',
            'fields': 'nextPageToken,files(id,name)',
            'pageSize': '100',
            'pageToken': ?page,
          },
        ),
      );
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      for (final f in (j['files'] as List? ?? const [])) {
        final m = f as Map<String, dynamic>;
        out[m['name'] as String] = m['id'] as String;
      }
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  @override
  Future<Map<String, String>> readAll() async {
    final out = <String, String>{};
    for (final MapEntry(key: name, value: id) in (await _list()).entries) {
      final res = await _send(
        'GET',
        Uri.parse('$_api/$id').replace(queryParameters: {'alt': 'media'}),
      );
      out[name] = utf8.decode(res.bodyBytes);
    }
    return out;
  }

  @override
  Future<void> write(String name, String content) async {
    final id = (await _list())[name];
    if (id != null) {
      await _send(
        'PATCH',
        Uri.parse('$_upload/$id')
            .replace(queryParameters: {'uploadType': 'media'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: utf8.encode(content),
      );
      return;
    }
    const boundary = 'tibyan-sync-boundary';
    final meta = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
    });
    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$meta\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--';
    await _send(
      'POST',
      Uri.parse(_upload).replace(queryParameters: {'uploadType': 'multipart'}),
      headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
      body: utf8.encode(body),
    );
  }

  @override
  Future<void> deleteAll() async {
    for (final id in (await _list()).values) {
      await _send('DELETE', Uri.parse('$_api/$id'));
    }
  }

  @override
  Future<void> disconnect() async => signOut?.call();
}

class DriveException implements Exception {
  const DriveException(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'DriveException($status)';
}

/// google_sign_in, set up once with [googleServerClientId].
class _GoogleAuth {
  Future<void>? _init;

  Future<void> _ready() => _init ??= GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId,
  );

  Future<String?> token({required bool interactive}) async {
    await _ready();
    final client = GoogleSignIn.instance.authorizationClient;
    final have = await client.authorizationForScopes([driveAppDataScope]);
    if (have != null) return have.accessToken;
    if (!interactive) return null;
    await GoogleSignIn.instance.authenticate(scopeHint: [driveAppDataScope]);
    final got = await client.authorizeScopes([driveAppDataScope]);
    return got.accessToken;
  }

  Future<void> forget(String token) async {
    await _ready();
    await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
      accessToken: token,
    );
  }

  Future<void> signOut() async {
    await _ready();
    await GoogleSignIn.instance.disconnect();
  }
}
