import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// The native side of the misbaha: the bead's click, counting with the
/// volume buttons while the app is open, and the home screen widget.
abstract interface class TasbihPlatform {
  /// Plays the bundled click (assets/tasbih/click.wav), with no delay.
  Future<void> click();

  /// While on, the volume buttons count (and do not change the volume).
  Future<void> setVolumeKeys(bool on);

  /// A volume button press, while [setVolumeKeys] is on.
  Stream<void> get volumeKey;

  /// Counts made on the home screen widget since the last call; the
  /// counter is emptied.
  Future<int> takePending();

  /// What the home screen widget shows. For a dhikr said in stages,
  /// [stages] is their counts (`33,33,33,1`) and [round] the count in the
  /// current round, so the widget shows the stage as it counts.
  Future<void> writeWidget({
    required String dhikr,
    required String count,
    required String label,
    String stages = '',
    int round = 0,
  });
}

class NoTasbihPlatform implements TasbihPlatform {
  int clicks = 0;
  bool volumeKeys = false;
  int pending = 0;
  Map<String, String>? widget;
  final _keys = StreamController<void>.broadcast();

  void pressVolume() => _keys.add(null);

  @override
  Future<void> click() async => clicks++;

  @override
  Future<void> setVolumeKeys(bool on) async => volumeKeys = on;

  @override
  Stream<void> get volumeKey => _keys.stream;

  @override
  Future<int> takePending() async {
    final n = pending;
    pending = 0;
    return n;
  }

  @override
  Future<void> writeWidget({
    required String dhikr,
    required String count,
    required String label,
    String stages = '',
    int round = 0,
  }) async => widget = {
    'dhikr': dhikr,
    'count': count,
    'label': label,
    'stages': stages,
    'round': '$round',
  };
}

class ChannelTasbihPlatform implements TasbihPlatform {
  ChannelTasbihPlatform() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey') _keys.add(null);
    });
  }

  static const _channel = MethodChannel('app.tibyan/tasbih');

  /// The keys the widgets read (docs/HOME_WIDGET.md).
  static const androidProvider = 'app.tibyan.tibyan.TasbihWidgetProvider';
  static const iosKind = 'TibyanTasbihWidget';
  static const pendingKey = 'tasbih_pending';

  final _keys = StreamController<void>.broadcast();

  Future<void> _group() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.setAppGroupId('group.app.tibyan.tibyan');
    }
  }

  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _call(String method, [Object? args]) async {
    if (!_mobile) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // A platform without the channel: nothing to do.
    } on PlatformException {
      // The sound or the service could not start; counting goes on.
    }
  }

  @override
  Future<void> click() => _call('click');

  @override
  Future<void> setVolumeKeys(bool on) => _call('setVolumeKeys', on);

  @override
  Stream<void> get volumeKey => _keys.stream;

  @override
  Future<int> takePending() async {
    if (!_mobile) return 0;
    var n = 0;
    try {
      await _group();
      final w = await HomeWidget.getWidgetData<int>(pendingKey);
      if (w != null && w > 0) {
        n += w;
        await HomeWidget.saveWidgetData<int>(pendingKey, 0);
      }
    } on Object {
      // No widget storage (no App Group yet).
    }
    return n;
  }

  @override
  Future<void> writeWidget({
    required String dhikr,
    required String count,
    required String label,
    String stages = '',
    int round = 0,
  }) async {
    if (!_mobile) return;
    try {
      await _group();
      await HomeWidget.saveWidgetData<String>('tasbih_dhikr', dhikr);
      await HomeWidget.saveWidgetData<String>('tasbih_count', count);
      await HomeWidget.saveWidgetData<String>('tasbih_label', label);
      await HomeWidget.saveWidgetData<String>('tasbih_stages', stages);
      await HomeWidget.saveWidgetData<int>('tasbih_round', round);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iosKind,
      );
    } on Object {
      // The widget is not set up on this device.
    }
  }
}
