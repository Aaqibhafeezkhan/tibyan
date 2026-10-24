import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../domain/memorize_session.dart';

/// The reader's choices in memorization mode, kept between sessions: how
/// the words are hidden, and whether reciting aloud reveals them.
class MemorizePrefs {
  const MemorizePrefs({this.style = MaskStyle.all, this.byVoice = false});

  final MaskStyle style;
  final bool byVoice;

  MemorizePrefs copyWith({MaskStyle? style, bool? byVoice}) => MemorizePrefs(
    style: style ?? this.style,
    byVoice: byVoice ?? this.byVoice,
  );
}

class MemorizePrefsController extends Notifier<MemorizePrefs> {
  static const _kStyle = 'memorize.style';
  static const _kVoice = 'memorize.byVoice';

  @override
  MemorizePrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return MemorizePrefs(
      style:
          MaskStyle.values.asNameMap()[prefs.getString(_kStyle) ?? ''] ??
          MaskStyle.all,
      byVoice: prefs.getBool(_kVoice) ?? false,
    );
  }

  Future<void> setStyle(MaskStyle style) async {
    state = state.copyWith(style: style);
    await ref.read(sharedPreferencesProvider).setString(_kStyle, style.name);
  }

  Future<void> setByVoice(bool on) async {
    state = state.copyWith(byVoice: on);
    await ref.read(sharedPreferencesProvider).setBool(_kVoice, on);
  }
}

final memorizePrefsProvider =
    NotifierProvider<MemorizePrefsController, MemorizePrefs>(
      MemorizePrefsController.new,
    );
