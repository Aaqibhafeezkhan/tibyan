import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// In-app updates for the Windows installer build.
///
/// The feed (`latest.json`, published by scripts/build-win-remote.sh) names
/// the newest Setup.exe with its SHA-256. A newer version is downloaded in the
/// background, verified, and run silently (`/S /RELAUNCH`) when the reader
/// presses «أعد التشغيل للتحديث». Other platforms never start it.
const windowsFeedUrl = 'https://tibyan.ahmedhelal.dev/win/latest.json';

/// Installers are only accepted from here, whatever the feed says.
const windowsInstallerPrefix = 'https://tibyan.ahmedhelal.dev/win/';

class UpdateFeed {
  const UpdateFeed({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    required this.size,
    this.notes,
  });

  final String version;
  final int build;
  final String url;
  final String sha256;
  final int size;
  final String? notes;

  /// Null when the feed is malformed or points outside [windowsInstallerPrefix].
  static UpdateFeed? tryParse(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final url = json['url'];
    final sha = json['sha256'];
    final build = json['build'];
    final size = json['size'];
    if (version is! String || parseVersion(version) == null) return null;
    if (url is! String || !url.startsWith(windowsInstallerPrefix)) return null;
    if (sha is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha)) {
      return null;
    }
    final notes = json['notes'];
    return UpdateFeed(
      version: version,
      build: build is int ? build : 0,
      url: url,
      sha256: sha.toLowerCase(),
      size: size is int ? size : 0,
      notes: notes is String && notes.isNotEmpty ? notes : null,
    );
  }
}

/// `0.8.2` -> [0, 8, 2]; null when not three numbers.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(v.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// True when [feed] is newer than the running version+build. The build
/// number breaks ties (a rebuild of the same version).
bool isNewer(UpdateFeed feed, String currentVersion, int currentBuild) {
  final a = parseVersion(feed.version);
  final b = parseVersion(currentVersion);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return feed.build > currentBuild;
}

/// SHA-256 of [file], streamed (the installer is ~100 MB).
Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<bool> verifySha256(File file, String expected) async =>
    (await sha256OfFile(file)) == expected.toLowerCase();

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.feed, this.progress);
  final UpdateFeed feed;

  /// 0..1, or null when the size is unknown.
  final double? progress;
}

class UpdateReady extends UpdateState {
  const UpdateReady(this.feed, this.installer);
  final UpdateFeed feed;
  final File installer;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);
  final String message;
}

typedef InstallerLauncher = Future<void> Function(File installer);

Future<void> _launchSilent(File installer) async {
  await Process.start(installer.path, const [
    '/S',
    '/RELAUNCH',
  ], mode: ProcessStartMode.detached);
  exit(0);
}

class WindowsUpdater extends ValueNotifier<UpdateState> {
  WindowsUpdater({
    http.Client? client,
    Future<(String, int)> Function()? currentVersion,
    this.downloadDir,
    InstallerLauncher? launch,
    this.feedUrl = windowsFeedUrl,
  }) : _client = client ?? http.Client(),
       _currentVersion = currentVersion ?? _packageVersion,
       _launch = launch ?? _launchSilent,
       super(const UpdateIdle());

  static Future<(String, int)> _packageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (info.version, int.tryParse(info.buildNumber) ?? 0);
  }

  final http.Client _client;
  final Future<(String, int)> Function() _currentVersion;
  final Directory? downloadDir;
  final InstallerLauncher _launch;
  final String feedUrl;
  Timer? _first;
  Timer? _periodic;
  Future<void>? _running;

  /// Windows release builds only: first check after 10 s, then every 4 h.
  static bool get supported => !kIsWeb && Platform.isWindows;

  void start() {
    if (!supported || _first != null) return;
    _first = Timer(const Duration(seconds: 10), check);
    _periodic = Timer.periodic(const Duration(hours: 4), (_) => check());
  }

  /// Checks the feed and, when newer, downloads and verifies the installer.
  /// A check while one runs, or once an update is ready, does nothing.
  Future<void> check() {
    if (value is UpdateReady) return Future.value();
    return _running ??= _check().whenComplete(() => _running = null);
  }

  Future<void> _check() async {
    value = const UpdateChecking();
    try {
      final res = await _client
          .get(Uri.parse(feedUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw HttpException('feed ${res.statusCode}');
      final feed = UpdateFeed.tryParse(jsonDecode(res.body));
      if (feed == null) throw const FormatException('bad feed');
      final (version, build) = await _currentVersion();
      if (!isNewer(feed, version, build)) {
        value = const UpdateUpToDate();
        return;
      }
      value = UpdateReady(feed, await _download(feed));
    } catch (e) {
      debugPrint('windows update: $e');
      value = UpdateFailed('$e');
    }
  }

  Future<File> _download(UpdateFeed feed) async {
    final dir =
        downloadDir ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'tibyan-update',
        );
    await dir.create(recursive: true);
    final name = Uri.parse(feed.url).pathSegments.last;
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    // Already downloaded earlier (same version): reuse it once it verifies.
    if (await file.exists() && await verifySha256(file, feed.sha256)) {
      return file;
    }
    final part = File('${file.path}.part');
    value = UpdateDownloading(feed, feed.size > 0 ? 0 : null);
    final res = await _client.send(http.Request('GET', Uri.parse(feed.url)));
    if (res.statusCode != 200) {
      throw HttpException('download ${res.statusCode}');
    }
    final total = feed.size > 0 ? feed.size : (res.contentLength ?? 0);
    final sink = part.openWrite();
    var got = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) {
          value = UpdateDownloading(feed, (got / total).clamp(0.0, 1.0));
        }
      }
    } finally {
      await sink.close();
    }
    if (!await verifySha256(part, feed.sha256)) {
      await part.delete();
      throw const FormatException('sha256 mismatch');
    }
    if (await file.exists()) {
      await file.delete();
    }
    return part.rename(file.path);
  }

  /// Runs the verified installer silently; it closes and restarts the app.
  Future<void> install() async {
    final s = value;
    if (s is! UpdateReady) return;
    if (!await verifySha256(s.installer, s.feed.sha256)) {
      value = const UpdateFailed('sha256 mismatch');
      return;
    }
    await _launch(s.installer);
  }

  @override
  void dispose() {
    _first?.cancel();
    _periodic?.cancel();
    _client.close();
    super.dispose();
  }
}

/// The app-wide updater; [WindowsUpdater.start] is a no-op off Windows.
final windowsUpdater = WindowsUpdater();
