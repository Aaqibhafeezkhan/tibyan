import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the recitation's Live Activity shows: names and numbers only (the
/// reciter, the surah, the verse number), never the Quran's text.
@immutable
class RecitationActivityContent {
  const RecitationActivityContent({
    required this.reciter,
    required this.surah,
    required this.verse,
    required this.playing,
    required this.playLabel,
    required this.pauseLabel,
    required this.rtl,
  });

  final String reciter;
  final String surah;
  final String verse;
  final bool playing;
  final String playLabel;
  final String pauseLabel;
  final bool rtl;

  Map<String, Object> toMap() => {
    'reciter': reciter,
    'surah': surah,
    'verse': verse,
    'playing': playing,
    'playLabel': playLabel,
    'pauseLabel': pauseLabel,
    'rtl': rtl,
  };

  @override
  bool operator ==(Object other) =>
      other is RecitationActivityContent &&
      other.reciter == reciter &&
      other.surah == surah &&
      other.verse == verse &&
      other.playing == playing &&
      other.playLabel == playLabel &&
      other.pauseLabel == pauseLabel &&
      other.rtl == rtl;

  @override
  int get hashCode =>
      Object.hash(reciter, surah, verse, playing, playLabel, pauseLabel, rtl);
}

/// The platform side of the Live Activity.
abstract interface class RecitationActivityHost {
  Future<void> update(RecitationActivityContent content);
  Future<void> end();
  set onToggle(void Function()? handler);
}

/// iOS (16.2+, ios/Runner/LiveActivityChannel.swift) through
/// `app.tibyan/live_activity`. A failure is ignored: the Live Activity is
/// an extra, the recitation never depends on it.
class ChannelRecitationActivity implements RecitationActivityHost {
  ChannelRecitationActivity({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.tibyan/live_activity') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'toggle') _onToggle?.call();
      return null;
    });
  }

  final MethodChannel _channel;
  void Function()? _onToggle;

  @override
  set onToggle(void Function()? handler) => _onToggle = handler;

  @override
  Future<void> update(RecitationActivityContent content) async {
    try {
      await _channel.invokeMethod<bool>('update', content.toMap());
    } catch (_) {}
  }

  @override
  Future<void> end() async {
    try {
      await _channel.invokeMethod<bool>('end');
    } catch (_) {}
  }
}

/// Keeps the Live Activity in step with the recitation: shown while the
/// player is active, updated only when what it shows changes (the verse,
/// play/pause), ended when the player goes. Calls are sent one after the
/// other, never piled up.
class RecitationActivitySync {
  RecitationActivitySync(this._host);

  final RecitationActivityHost _host;
  RecitationActivityContent? _shown;
  Future<void> _last = Future.value();

  /// Ends one left over from an earlier run (the app was closed).
  Future<void> start() => _enqueue(_host.end);

  /// [content] null: the recitation has stopped.
  Future<void> show(RecitationActivityContent? content) {
    if (content == _shown) return _last;
    final had = _shown != null;
    _shown = content;
    if (content == null) return had ? _enqueue(_host.end) : _last;
    return _enqueue(() => _host.update(content));
  }

  Future<void> _enqueue(Future<void> Function() call) =>
      _last = _last.then((_) => call()).catchError((_) {});

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}
