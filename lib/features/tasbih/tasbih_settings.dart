import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_controller.dart'
    show sharedPreferencesProvider;

/// How the misbaha is drawn.
enum TasbihStyle {
  /// Beads on a string; one is drawn down along it (the default).
  misbaha,

  /// One large round button.
  button,

  /// An electronic counter with a seven-segment display.
  lcd,

  /// The whole screen is the target, in the theme's own calm colours.
  screen,
}

/// How the misbaha's beads are rendered.
enum MisbahaRender {
  /// «إيحاء ثلاثي الأبعاد»: flat circles shaded to look round.
  suggested,

  /// «ثلاثي الأبعاد حقيقي»: spheres placed in 3D, seen through a
  /// perspective camera and lit per pixel.
  real,
}

/// The beads' material.
enum BeadMaterial { amber, wood, pearl }

/// The misbaha's settings, kept under `settings.tasbih.*` so a backup
/// carries them.
@immutable
class TasbihSettings {
  const TasbihSettings({
    this.style = TasbihStyle.misbaha,
    this.render = MisbahaRender.suggested,
    this.material = BeadMaterial.amber,
    this.haptics = true,
    this.sound = false,
    this.keepScreenOn = true,
    this.volumeKeys = false,
    this.lockScreen = false,
    this.dhikr,
    this.target = 33,
  });

  final TasbihStyle style;
  final MisbahaRender render;
  final BeadMaterial material;

  /// A light tap with each count; a stronger one when a round closes.
  final bool haptics;

  /// The bead's click with each count.
  final bool sound;
  final bool keepScreenOn;

  /// Count with the volume buttons while the misbaha is open.
  final bool volumeKeys;

  /// Android only: keep counting with the volume buttons while the screen
  /// is locked, through a foreground service and its notification.
  final bool lockScreen;

  /// The key of the dhikr being counted; null for the first.
  final String? dhikr;

  /// The count to a round; null for none.
  final int? target;

  TasbihSettings copyWith({
    TasbihStyle? style,
    MisbahaRender? render,
    BeadMaterial? material,
    bool? haptics,
    bool? sound,
    bool? keepScreenOn,
    bool? volumeKeys,
    bool? lockScreen,
    String? dhikr,
    int? Function()? target,
  }) => TasbihSettings(
    style: style ?? this.style,
    render: render ?? this.render,
    material: material ?? this.material,
    haptics: haptics ?? this.haptics,
    sound: sound ?? this.sound,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    volumeKeys: volumeKeys ?? this.volumeKeys,
    lockScreen: lockScreen ?? this.lockScreen,
    dhikr: dhikr ?? this.dhikr,
    target: target != null ? target() : this.target,
  );
}

final tasbihSettingsProvider =
    NotifierProvider<TasbihSettingsController, TasbihSettings>(
      TasbihSettingsController.new,
    );

class TasbihSettingsController extends Notifier<TasbihSettings> {
  static const _p = 'settings.tasbih.';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  TasbihSettings build() {
    final p = _prefs;
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == p.getString('$_p$key')).firstOrNull ??
        fallback;
    const d = TasbihSettings();
    final target = p.getInt('${_p}target');
    return TasbihSettings(
      style: pick(TasbihStyle.values, 'style', d.style),
      render: pick(MisbahaRender.values, 'render', d.render),
      material: pick(BeadMaterial.values, 'material', d.material),
      haptics: p.getBool('${_p}haptics') ?? d.haptics,
      sound: p.getBool('${_p}sound') ?? d.sound,
      keepScreenOn: p.getBool('${_p}keepScreenOn') ?? d.keepScreenOn,
      volumeKeys: p.getBool('${_p}volumeKeys') ?? d.volumeKeys,
      lockScreen: p.getBool('${_p}lockScreen') ?? d.lockScreen,
      dhikr: p.getString('${_p}dhikr'),
      // 0 is kept for «no target».
      target: target == null ? d.target : (target <= 0 ? null : target),
    );
  }

  Future<void> setStyle(TasbihStyle v) async {
    state = state.copyWith(style: v);
    await _prefs.setString('${_p}style', v.name);
  }

  Future<void> setRender(MisbahaRender v) async {
    state = state.copyWith(render: v);
    await _prefs.setString('${_p}render', v.name);
  }

  Future<void> setMaterial(BeadMaterial v) async {
    state = state.copyWith(material: v);
    await _prefs.setString('${_p}material', v.name);
  }

  Future<void> setHaptics(bool v) async {
    state = state.copyWith(haptics: v);
    await _prefs.setBool('${_p}haptics', v);
  }

  Future<void> setSound(bool v) async {
    state = state.copyWith(sound: v);
    await _prefs.setBool('${_p}sound', v);
  }

  Future<void> setKeepScreenOn(bool v) async {
    state = state.copyWith(keepScreenOn: v);
    await _prefs.setBool('${_p}keepScreenOn', v);
  }

  Future<void> setVolumeKeys(bool v) async {
    state = state.copyWith(volumeKeys: v);
    await _prefs.setBool('${_p}volumeKeys', v);
  }

  Future<void> setLockScreen(bool v) async {
    state = state.copyWith(lockScreen: v);
    await _prefs.setBool('${_p}lockScreen', v);
  }

  Future<void> setDhikr(String key) async {
    state = state.copyWith(dhikr: key);
    await _prefs.setString('${_p}dhikr', key);
  }

  Future<void> setTarget(int? v) async {
    state = state.copyWith(target: () => v);
    await _prefs.setInt('${_p}target', v ?? 0);
  }
}
