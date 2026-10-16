import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/interface_style.dart';
import '../../../l10n/app_localizations.dart';
import '../tasbih_settings.dart';

String tasbihStyleName(AppLocalizations l, TasbihStyle s) => switch (s) {
  TasbihStyle.misbaha => l.tasbihStyleMisbaha,
  TasbihStyle.button => l.tasbihStyleButton,
  TasbihStyle.lcd => l.tasbihStyleLcd,
  TasbihStyle.screen => l.tasbihStyleScreen,
};

String beadMaterialName(AppLocalizations l, BeadMaterial m) => switch (m) {
  BeadMaterial.amber => l.tasbihMaterialAmber,
  BeadMaterial.wood => l.tasbihMaterialWood,
  BeadMaterial.pearl => l.tasbihMaterialPearl,
};

/// «شكل المسبحة»: the four styles; in elderly mode the big button is
/// marked as suggested.
class TasbihStylePicker extends ConsumerWidget {
  const TasbihStylePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final style = ref.watch(tasbihSettingsProvider.select((s) => s.style));
    final elderly = context.look.elderly;
    return RadioGroup<TasbihStyle>(
      groupValue: style,
      onChanged: (v) {
        if (v != null) ref.read(tasbihSettingsProvider.notifier).setStyle(v);
      },
      child: Column(
        children: [
          for (final s in TasbihStyle.values)
            RadioListTile<TasbihStyle>(
              value: s,
              title: Text(tasbihStyleName(l, s)),
              subtitle: elderly && s == TasbihStyle.button
                  ? Text(l.tasbihSuggestedElderly)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// «طريقة رسم الحبات»: suggested or true 3D.
class TasbihRenderPicker extends ConsumerWidget {
  const TasbihRenderPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final render = ref.watch(tasbihSettingsProvider.select((s) => s.render));
    return RadioGroup<MisbahaRender>(
      groupValue: render,
      onChanged: (v) {
        if (v != null) ref.read(tasbihSettingsProvider.notifier).setRender(v);
      },
      child: Column(
        children: [
          ListTile(
            title: Text(
              l.tasbihRender,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          RadioListTile<MisbahaRender>(
            value: MisbahaRender.suggested,
            title: Text(l.tasbihRenderSuggested),
            subtitle: Text(l.tasbihRenderSuggestedHint),
          ),
          RadioListTile<MisbahaRender>(
            value: MisbahaRender.real,
            title: Text(l.tasbihRenderReal),
            subtitle: Text(l.tasbihRenderRealHint),
          ),
        ],
      ),
    );
  }
}

/// «خامة الحبات».
class BeadMaterialPicker extends ConsumerWidget {
  const BeadMaterialPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final m = ref.watch(tasbihSettingsProvider.select((s) => s.material));
    return ListTile(
      title: Text(l.tasbihMaterial),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          children: [
            for (final v in BeadMaterial.values)
              ChoiceChip(
                label: Text(beadMaterialName(l, v)),
                selected: m == v,
                onSelected: (_) =>
                    ref.read(tasbihSettingsProvider.notifier).setMaterial(v),
              ),
          ],
        ),
      ),
    );
  }
}

/// A switch of the misbaha's settings.
class TasbihSwitch extends ConsumerWidget {
  const TasbihSwitch({
    super.key,
    required this.title,
    this.hint,
    required this.value,
    required this.set,
  });

  final String Function(AppLocalizations l) title;
  final String Function(AppLocalizations l)? hint;
  final bool Function(TasbihSettings s) value;
  final void Function(TasbihSettingsController c, bool v) set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(title(l)),
      subtitle: hint == null
          ? null
          : Text(hint!(l), style: TextStyle(color: context.look.sub)),
      value: ref.watch(tasbihSettingsProvider.select(value)),
      onChanged: (v) => set(ref.read(tasbihSettingsProvider.notifier), v),
    );
  }
}

/// Lock-screen counting is Android's only.
bool get lockScreenCountingAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
