import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/settings_controller.dart';

/// Where reports go.
final reportEndpoint = Uri.parse('https://altibyan.app/api/reports');

/// The kinds of report the form offers.
enum ReportType { bug, problem, suggestion, other }

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _phone = RegExp(r'^\+?[0-9\s\-]{6,20}$');

/// Null when [email] is empty or valid.
bool isValidReportEmail(String email) =>
    email.trim().isEmpty || _email.hasMatch(email.trim());

/// Null when [phone] is empty or looks like a phone number.
bool isValidReportPhone(String phone) =>
    phone.trim().isEmpty || _phone.hasMatch(phone.trim());

const reportMinLength = 5;
const reportMaxLength = 4000;

/// The device facts attached to every report, shown to the user first.
class ReportDevice {
  const ReportDevice({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
  });

  final String appVersion;
  final String platform;
  final String osVersion;

  static ReportDevice current(String appVersion) => ReportDevice(
    appVersion: appVersion,
    platform: kIsWeb ? 'web' : Platform.operatingSystem,
    osVersion: kIsWeb ? '' : _short(Platform.operatingSystemVersion),
  );

  static String _short(String s) => s.length > 64 ? s.substring(0, 64) : s;
}

class ProblemReport {
  const ProblemReport({
    required this.type,
    required this.description,
    this.phone = '',
    this.email = '',
    required this.device,
  });

  final ReportType type;
  final String description;
  final String phone;
  final String email;
  final ReportDevice device;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'description': description.trim(),
    if (phone.trim().isNotEmpty) 'phone': phone.trim(),
    if (email.trim().isNotEmpty) 'email': email.trim(),
    'app_version': device.appVersion,
    'platform': device.platform,
    'os_version': device.osVersion,
  };
}

/// What happened to a report on submit.
enum ReportOutcome { sent, queued, rateLimited, failed }

/// Sends reports; one that cannot be sent now (offline, server down) is
/// queued on the device and sent later. A small limit on the device keeps
/// a stuck button from flooding the server: at most [maxPerHour] reports
/// an hour, and [minGap] between two.
///
/// The queue holds at most [maxQueued] reports, each for [queueTtl] at
/// most: a report that could not go in that time is dropped, with the
/// phone and email it carried. A report leaves the queue (and the device)
/// as soon as it is sent.
class ReportService {
  ReportService(
    this._prefs, {
    http.Client? client,
    DateTime Function()? now,
    this.maxPerHour = 5,
    this.minGap = const Duration(seconds: 30),
    this.maxQueued = 10,
    this.queueTtl = const Duration(days: 14),
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final http.Client _client;
  final DateTime Function() _now;
  final int maxPerHour;
  final Duration minGap;
  final int maxQueued;
  final Duration queueTtl;

  static const queueKey = 'reports.queue';
  static const sentKey = 'reports.sentAt';

  /// The queued reports' bodies, oldest first, the expired ones left out.
  List<String> get queue => [for (final e in _entries()) e.body];

  /// The queue as stored: each entry `{"at": queuedAt, "body": json}`
  /// (when it was queued, and the report's JSON). An entry from before the dates were kept (the bare
  /// body) counts as queued now.
  List<({DateTime at, String body})> _entries() {
    final cutoff = _now().subtract(queueTtl);
    final out = <({DateTime at, String body})>[];
    for (final raw in _prefs.getStringList(queueKey) ?? const <String>[]) {
      DateTime at = _now();
      var body = raw;
      try {
        final v = jsonDecode(raw);
        if (v is Map && v['body'] is String && v['at'] is String) {
          at = DateTime.tryParse(v['at'] as String) ?? at;
          body = v['body'] as String;
        }
      } on FormatException {
        continue;
      }
      if (at.isAfter(cutoff)) out.add((at: at, body: body));
    }
    return out;
  }

  Future<void> _store(List<({DateTime at, String body})> entries) {
    final kept = entries.length > maxQueued
        ? entries.sublist(entries.length - maxQueued)
        : entries;
    if (kept.isEmpty) return _prefs.remove(queueKey);
    return _prefs.setStringList(queueKey, [
      for (final e in kept)
        jsonEncode({'at': e.at.toIso8601String(), 'body': e.body}),
    ]);
  }

  List<DateTime> _recent() {
    final cutoff = _now().subtract(const Duration(hours: 1));
    return [
      for (final s in _prefs.getStringList(sentKey) ?? const <String>[])
        if (DateTime.tryParse(s) case final t? when t.isAfter(cutoff)) t,
    ];
  }

  /// Whether the device limit allows another report now.
  bool get canSubmit {
    final recent = _recent();
    if (recent.length >= maxPerHour) return false;
    return recent.every((t) => _now().difference(t) >= minGap);
  }

  Future<ReportOutcome> submit(ProblemReport report) async {
    if (!canSubmit) return ReportOutcome.rateLimited;
    final body = jsonEncode(report.toJson());
    await _prefs.setStringList(sentKey, [
      for (final t in _recent()) t.toIso8601String(),
      _now().toIso8601String(),
    ]);
    final result = await _post(body);
    switch (result) {
      case _Post.ok:
        unawaited(flush());
        return ReportOutcome.sent;
      case _Post.retry:
        await _store([..._entries(), (at: _now(), body: body)]);
        return ReportOutcome.queued;
      case _Post.rejected:
        return ReportOutcome.failed;
    }
  }

  bool _flushing = false;

  /// Sends the queued reports, oldest first; stops at the first that
  /// still cannot go. Returns how many were sent.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      // The expired ones go first, contact details and all.
      await _store(_entries());
      while (true) {
        final entries = _entries();
        if (entries.isEmpty) break;
        final first = entries.first;
        final result = await _post(first.body);
        if (result == _Post.retry) break;
        // Sent, or rejected for good (never retry a report the server
        // refuses): either way it leaves the device.
        await _store(_entries().where((e) => e != first).toList());
        if (result == _Post.ok) sent++;
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<_Post> _post(String body) async {
    try {
      final res = await _client
          .post(
            reportEndpoint,
            headers: {'content-type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) return _Post.ok;
      if (res.statusCode == 429 || res.statusCode >= 500) return _Post.retry;
      return _Post.rejected;
    } catch (_) {
      return _Post.retry;
    }
  }
}

enum _Post { ok, retry, rejected }

final reportHttpClientProvider = Provider<http.Client>((ref) => http.Client());

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    ref.watch(sharedPreferencesProvider),
    client: ref.watch(reportHttpClientProvider),
  ),
);
