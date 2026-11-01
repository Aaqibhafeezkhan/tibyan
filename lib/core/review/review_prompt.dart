import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings_controller.dart';

/// What makes a moment worth the store's review sheet.
enum ReviewMoment { khatmaComplete, readingDays }

/// When the store's own review sheet may be asked for: after a positive
/// moment (a khatma completed, or the seventh distinct reading day), never
/// on the day of the first launch, at most once per version, and at least
/// [cooldown] after the last ask. The store decides whether it shows; the
/// app never asks for a rating itself.
@immutable
class ReviewPolicy {
  const ReviewPolicy({
    this.cooldown = const Duration(days: 120),
    this.readingDays = 7,
  });

  final Duration cooldown;
  final int readingDays;

  bool allows({
    required ReviewMoment moment,
    required DateTime now,
    required DateTime? firstSeen,
    required int distinctDays,
    required DateTime? lastAsked,
    required String? lastVersion,
    required String version,
  }) {
    if (firstSeen == null || _day(now) == _day(firstSeen)) return false;
    if (lastVersion == version) return false;
    if (lastAsked != null && now.difference(lastAsked) < cooldown) {
      return false;
    }
    return switch (moment) {
      ReviewMoment.khatmaComplete => true,
      ReviewMoment.readingDays => distinctDays >= readingDays,
    };
  }
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Keeps the reading days and the last ask, and asks the store.
class ReviewPrompt {
  ReviewPrompt(
    this._prefs, {
    this.policy = const ReviewPolicy(),
    Future<bool> Function()? available,
    Future<void> Function()? request,
    Future<String> Function()? version,
    DateTime Function()? clock,
    bool? supported,
  }) : _available = available ?? InAppReview.instance.isAvailable,
       _request = request ?? InAppReview.instance.requestReview,
       _version = version ?? _appVersion,
       _clock = clock ?? DateTime.now,
       _supported = supported ?? _mobile;

  static const firstSeenKey = 'review.firstSeen';
  static const daysKey = 'review.days';
  static const lastAskedKey = 'review.lastAsked';
  static const lastVersionKey = 'review.lastVersion';

  final SharedPreferences _prefs;
  final ReviewPolicy policy;
  final Future<bool> Function() _available;
  final Future<void> Function() _request;
  final Future<String> Function() _version;
  final DateTime Function() _clock;
  final bool _supported;

  static bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<String> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Notes the first launch; called once at startup.
  Future<void> noteLaunch() async {
    if (_prefs.getString(firstSeenKey) != null) return;
    await _prefs.setString(firstSeenKey, _clock().toIso8601String());
  }

  /// The distinct days with a reading session (only the last few kept).
  int get distinctDays => (_prefs.getStringList(daysKey) ?? const []).length;

  /// A reading session ended today; asks when it is the seventh day.
  Future<bool> readingSession({bool ask = true}) async {
    final today = _day(_clock());
    final days = _prefs.getStringList(daysKey) ?? const <String>[];
    if (!days.contains(today)) {
      final kept = [...days, today];
      // The count only has to reach the threshold.
      await _prefs.setStringList(
        daysKey,
        kept.length > policy.readingDays * 2
            ? kept.sublist(kept.length - policy.readingDays * 2)
            : kept,
      );
    }
    if (!ask) return false;
    return maybeAsk(ReviewMoment.readingDays);
  }

  /// Asks the store for its review sheet if [moment] qualifies; true when
  /// asked (the store may still show nothing).
  Future<bool> maybeAsk(ReviewMoment moment) async {
    if (!_supported) return false;
    try {
      final version = await _version();
      final now = _clock();
      final allowed = policy.allows(
        moment: moment,
        now: now,
        firstSeen: DateTime.tryParse(_prefs.getString(firstSeenKey) ?? ''),
        distinctDays: distinctDays,
        lastAsked: DateTime.tryParse(_prefs.getString(lastAskedKey) ?? ''),
        lastVersion: _prefs.getString(lastVersionKey),
        version: version,
      );
      if (!allowed || !await _available()) return false;
      await _prefs.setString(lastAskedKey, now.toIso8601String());
      await _prefs.setString(lastVersionKey, version);
      await _request();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final reviewPromptProvider = Provider<ReviewPrompt>(
  (ref) => ReviewPrompt(ref.read(sharedPreferencesProvider)),
);
