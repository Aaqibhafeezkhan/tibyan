import 'dart:convert';

import '../../core/ui/app_toast.dart';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../l10n/app_localizations.dart';
import '../khatma/khatma_providers.dart';
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/widgets/art_frame.dart';
import '../mushaf/presentation/widgets/fasil_bookmarks.dart';
import '../mushaf/presentation/widgets/fasil_sheet.dart' show FasilPreview;
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../mushaf/presentation/widgets/theme_art.dart';
import '../tasmee/data/tasmee_settings.dart';
import 'theme_picker.dart';

// The settings' own controls, placed by settings_catalog.dart into the
// sections of the settings grid.

/// The app's version as built (pubspec.yaml), e.g. `0.4.0 (5)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});

/// «شكل الواجهة»: the three interface styles as small previews; the
/// choice applies at once.
class InterfaceStylePicker extends ConsumerWidget {
  const InterfaceStylePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final chosen = ref.watch(settingsProvider.select((s) => s.interfaceStyle));
    final names = {
      InterfaceStyle.makhtuta: l.interfaceStyleMakhtuta,
      InterfaceStyle.handasi: l.interfaceStyleHandasi,
      InterfaceStyle.layli: l.interfaceStyleLayli,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.interfaceStyleTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: look.ink,
            ),
          ),
          Text(
            l.interfaceStyleHint,
            style: TextStyle(fontSize: 13, color: look.sub),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final style in InterfaceStyle.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _StyleSwatch(
                      key: ValueKey('interfaceStyle.${style.name}'),
                      preview: UiLook.of(
                        style,
                        night: look.night,
                        white: look.isWhite,
                      ),
                      name: names[style]!,
                      selected: style == chosen,
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .setInterfaceStyle(style),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({
    super.key,
    required this.preview,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final UiLook preview;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final p = preview;
    final Widget art = switch (p.style) {
      InterfaceStyle.makhtuta => Container(
        color: p.frame,
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.gold),
          ),
          child: Center(
            child: SizedBox.square(
              dimension: 30,
              child: CustomPaint(painter: StarPainter(p.surface, p.gold)),
            ),
          ),
        ),
      ),
      InterfaceStyle.handasi => ColoredBox(
        color: p.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: GirihPainter(
                  p.accent.withValues(alpha: .25),
                  cell: 22,
                ),
              ),
            ),
            Center(
              child: SizedBox.square(
                dimension: 30,
                child: CustomPaint(painter: StarPainter(p.accent, p.accent)),
              ),
            ),
          ],
        ),
      ),
      InterfaceStyle.layli => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.frame, p.night ? p.surface : const Color(0xFF223459)],
          ),
        ),
        child: CustomPaint(
          painter: SkyPainter(const Color(0xFFE6C47A)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: CustomPaint(
              painter: ArchBorder(const Color(0xFFE6C47A), spring: .5),
            ),
          ),
        ),
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? look.control : look.line,
                  width: selected ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 9 : 11),
                child: SizedBox.expand(child: art),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check_circle, size: 16, color: look.control),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? look.ink : look.sub,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final text = await Backup(
      ref.read(userDatabaseProvider),
      prefs: ref.read(sharedPreferencesProvider),
    ).export();
    final dir = await getTemporaryDirectory();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/tibyan-backup-$day.json');
    await file.writeAsString(text, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (_) {
    messenger.showSnackBar(appToast(content: Text(l.backupFailed)));
  }
}

Future<void> importBackup(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final digits = NumberFormatter(Localizations.localeOf(context));
  try {
    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Tibyan backup', extensions: ['json']),
      ],
    );
    if (picked == null) return;
    final text = utf8.decode(await picked.readAsBytes());
    final r = await Backup(
      ref.read(userDatabaseProvider),
      prefs: ref.read(sharedPreferencesProvider),
    ).import(text);
    // The restored settings take effect now, and the khatmas' and the
    // hifz's progress is worked out again from the restored record.
    if (r.settings > 0) {
      ref
        ..invalidate(settingsProvider)
        ..invalidate(tasmeeSettingsProvider)
        ..invalidate(streakNotesProvider);
    }
    try {
      await ref.read(khatmaServiceProvider).afterRestore();
    } on Object catch (e) {
      // The restore itself is done; the caches follow at the next start.
      debugPrint('after restore: $e');
    }
    messenger.showSnackBar(
      appToast(content: Text(l.backupDone(digits(r.added), digits(r.updated)))),
    );
  } on BackupException {
    messenger.showSnackBar(appToast(content: Text(l.backupInvalid)));
  } catch (_) {
    messenger.showSnackBar(appToast(content: Text(l.backupFailed)));
  }
}

/// «وضع التركيز»: the switch, how the tools are reached, and how the page
/// fills the screen.
class FocusModeCard extends ConsumerWidget {
  const FocusModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final muted = TextStyle(color: context.look.sub);
    Widget label(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.fullscreen),
          title: Text(l.focusModeTitle),
          subtitle: Text(l.focusModeHint, style: muted),
          value: settings.focusMode,
          onChanged: controller.setFocusMode,
        ),
        const Divider(height: 1),
        label(l.focusToolsLabel),
        RadioGroup<FocusTools>(
          groupValue: settings.focusTools,
          onChanged: (v) => v == null ? null : controller.setFocusTools(v),
          child: Column(
            children: [
              for (final (v, name, hint) in [
                (FocusTools.button, l.focusToolsButton, l.focusToolsButtonHint),
                (FocusTools.menu, l.focusToolsMenu, l.focusToolsMenuHint),
              ])
                RadioListTile(
                  value: v,
                  title: Text(name),
                  subtitle: Text(hint, style: muted),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        label(l.pageFillLabel),
        RadioGroup<PageFill>(
          groupValue: settings.pageFill,
          onChanged: (v) => v == null ? null : controller.setPageFill(v),
          child: Column(
            children: [
              for (final (v, name, hint) in [
                (PageFill.lines, l.pageFillLines, l.pageFillLinesHint),
                (PageFill.stretch, l.pageFillStretch, l.pageFillStretchHint),
                (PageFill.full, l.pageFillFull, l.pageFillFullHint),
              ])
                RadioListTile(
                  value: v,
                  title: Text(name),
                  subtitle: Text(hint, style: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «مؤقت سجدات التلاوة»: on or off, and the card's countdown.
class SajdahTimerCard extends ConsumerWidget {
  const SajdahTimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.look;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final digits = NumberFormatter(Localizations.localeOf(context));
    return Column(
      children: [
        SwitchListTile(
          secondary: ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/ornaments/sajdah.svg',
              height: 24,
              colorFilter: ColorFilter.mode(t.sub, BlendMode.srcIn),
            ),
          ),
          title: Text(l.sajdahTimer),
          subtitle: Text(l.sajdahTimerHint, style: TextStyle(color: t.sub)),
          value: settings.sajdahTimer,
          onChanged: controller.setSajdahTimer,
        ),
        // The length shows only while the timer is on.
        if (settings.sajdahTimer) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.sajdahTimerLength,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in sajdahTimerLengths)
                      ChoiceChip(
                        label: Text(l.seconds(digits(n))),
                        selected: settings.sajdahSeconds == n,
                        onSelected: (_) => controller.setSajdahSeconds(n),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// «شكل المشغل»: how the player over the mushaf looks, with focus mode on
/// or off.
/// «شكل الفاصلة»: the look of named fawasil on the page (tinted verse,
/// fabric ribbon, card tab), the ribbon's cloth and tassel, and where
/// ribbons and tabs sit, with a live preview.
class FasilStyleCard extends ConsumerWidget {
  const FasilStyleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final style = s.effectiveFasilStyle;
    final muted = TextStyle(color: context.look.sub);
    Widget label(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 6),
      child: Text(text, style: muted),
    );
    Widget seg<T>(T value, List<(T, String)> options, void Function(T) set) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final (v, name) in options)
                ButtonSegment(value: v, label: Text(name)),
            ],
            selected: {value},
            onSelectionChanged: (v) => set(v.first),
          ),
        );
    final hint = switch (style) {
      FasilStyle.tint => l.fasilStyleTintHint,
      FasilStyle.ribbon => l.fasilStyleRibbonHint,
      FasilStyle.tab => l.fasilStyleTabHint,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
          child: Text(
            l.fasilStyleLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 8),
          child: Text(l.fasilStyleHint, style: muted),
        ),
        seg(style, [
          (FasilStyle.tint, l.fasilStyleTint),
          (FasilStyle.ribbon, l.fasilStyleRibbon),
          (FasilStyle.tab, l.fasilStyleTab),
        ], ctrl.setFasilStyle),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
          child: Text(hint, style: muted),
        ),
        if (style == FasilStyle.ribbon) ...[
          label(l.fasilMaterialLabel),
          seg(s.fasilMaterial, [
            (FasilMaterial.silk, l.fasilSilk),
            (FasilMaterial.linen, l.fasilLinen),
            (FasilMaterial.velvet, l.fasilVelvet),
          ], ctrl.setFasilMaterial),
          SwitchListTile(
            title: Text(l.fasilTassel),
            value: s.fasilTassel,
            onChanged: ctrl.setFasilTassel,
          ),
        ],
        if (style != FasilStyle.tint) ...[
          label(l.fasilPlaceLabel),
          seg(s.fasilPlace, [
            (FasilPlace.top, l.fasilPlaceTop),
            (FasilPlace.side, l.fasilPlaceSide),
          ], ctrl.setFasilPlace),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Semantics(
            label: l.fasilPreview,
            child: Center(
              child: SizedBox(
                width: 180,
                child: FasilPreview(
                  key: ValueKey('fasil-preview-${style.name}'),
                  look: FasilLook.of(context, s),
                  height: 170,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A phone held sideways: the page fitted to the width or to the height.
class LandscapeFitCard extends ConsumerWidget {
  const LandscapeFitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(color: context.look.sub);
    return RadioGroup<LandscapeFit>(
      groupValue: ref.watch(settingsProvider.select((s) => s.landscapeFit)),
      onChanged: (v) => v == null
          ? null
          : ref.read(settingsProvider.notifier).setLandscapeFit(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: Text(
              l.landscapeFitLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (v, name, hint) in [
            (LandscapeFit.width, l.landscapeFitWidth, l.landscapeFitWidthHint),
            (LandscapeFit.page, l.landscapeFitPage, l.landscapeFitPageHint),
          ])
            RadioListTile(
              value: v,
              title: Text(name),
              subtitle: Text(hint, style: muted),
            ),
        ],
      ),
    );
  }
}

/// «تأثير قلب الصفحة»: how the mushaf turns a page.
class PageTurnCard extends ConsumerWidget {
  const PageTurnCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(color: context.look.sub);
    return RadioGroup<PageTurn>(
      groupValue: ref.watch(settingsProvider.select((s) => s.pageTurn)),
      onChanged: (v) =>
          v == null ? null : ref.read(settingsProvider.notifier).setPageTurn(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: Text(
              l.pageTurnLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (v, name, hint) in [
            (PageTurn.normal, l.pageTurnNormal, l.pageTurnNormalHint),
            (PageTurn.curl, l.pageTurnCurl, l.pageTurnCurlHint),
            (PageTurn.bend, l.pageTurnBend, l.pageTurnBendHint),
            (PageTurn.fold, l.pageTurnFold, l.pageTurnFoldHint),
            (PageTurn.fade, l.pageTurnFade, l.pageTurnFadeHint),
          ])
            RadioListTile(
              value: v,
              title: Text(name),
              subtitle: Text(hint, style: muted),
            ),
        ],
      ),
    );
  }
}

class PlayerStyleCard extends ConsumerWidget {
  const PlayerStyleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(color: context.look.sub);
    return RadioGroup<PlayerStyle>(
      groupValue: ref.watch(settingsProvider.select((s) => s.playerStyle)),
      onChanged: (v) => v == null
          ? null
          : ref.read(settingsProvider.notifier).setPlayerStyle(v),
      child: Column(
        children: [
          for (final (v, name, hint) in [
            (PlayerStyle.auto, l.playerStyleAuto, l.playerStyleAutoHint),
            (PlayerStyle.normal, l.playerStyleNormal, null),
            (PlayerStyle.pill, l.playerStylePill, l.playerStylePillHint),
            (PlayerStyle.button, l.playerStyleButton, l.playerStyleButtonHint),
          ])
            RadioListTile(
              value: v,
              title: Text(name),
              subtitle: hint == null ? null : Text(hint, style: muted),
            ),
        ],
      ),
    );
  }
}

/// «وضع الإضاءة», right under the interface style: it lights the whole app,
/// the mushaf pages included.
class LightModePicker extends ConsumerWidget {
  const LightModePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final controller = ref.read(settingsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.modeLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: look.ink,
            ),
          ),
          RadioGroup<ModeSetting>(
            groupValue: mode,
            onChanged: (v) => v == null ? null : controller.setMode(v),
            child: Column(
              children: [
                RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  value: ModeSetting.system,
                  title: Text(l.modeSystem),
                  subtitle: Text(
                    l.modeSystemHint,
                    style: TextStyle(color: look.sub),
                  ),
                ),
                for (final (v, name) in [
                  (ModeSetting.light, l.modeLight),
                  (ModeSetting.white, l.modeWhite),
                  (ModeSetting.night, l.modeNight),
                  (ModeSetting.black, l.modeBlack),
                ])
                  RadioListTile(
                    contentPadding: EdgeInsets.zero,
                    value: v,
                    title: Text(name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that opens another screen; the chevron mirrors itself (left in
/// Arabic, right in English).
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.look;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(subtitle!, style: TextStyle(color: t.sub)),
      trailing: Icon(Icons.chevron_right, color: t.sub),
      onTap: onTap,
    );
  }
}

/// «اللغة»: the interface language.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return RadioGroup<LanguageSetting>(
      groupValue: language,
      onChanged: (v) =>
          v == null ? null : ref.read(settingsProvider.notifier).setLanguage(v),
      child: Column(
        children: [
          for (final (v, name) in [
            (LanguageSetting.system, l.languageSystem),
            (LanguageSetting.ar, l.languageArabic),
            (LanguageSetting.en, l.languageEnglish),
          ])
            RadioListTile(value: v, title: Text(name)),
        ],
      ),
    );
  }
}

/// «خط الواجهة»: each face named in itself.
class UiFontPicker extends ConsumerWidget {
  const UiFontPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final font = ref.watch(settingsProvider.select((s) => s.uiFont));
    return RadioGroup<UiFont>(
      groupValue: font,
      onChanged: (v) =>
          v == null ? null : ref.read(settingsProvider.notifier).setUiFont(v),
      child: Column(
        children: [
          for (final (v, name) in [
            (UiFont.plex, l.uiFontPlex),
            (UiFont.kfgqpcAn, l.uiFontKfgqpcAn),
            (UiFont.changa, l.uiFontChanga),
          ])
            RadioListTile(
              value: v,
              title: Text(name, style: TextStyle(fontFamily: v.family)),
            ),
        ],
      ),
    );
  }
}

/// «شكل المصحف»: the page themes, the chosen one's description, and whose
/// ornaments they are.
class PageLookCard extends StatelessWidget {
  const PageLookCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.look;
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ThemePicker(),
          const SizedBox(height: 10),
          Text(
            context.tokens.style.localizedDescription(lang),
            style: TextStyle(color: t.sub, height: 1.5),
          ),
          if (context.tokens.style.art != null) ...[
            const SizedBox(height: 8),
            Text(
              l.themeArtCredit,
              style: TextStyle(color: t.sub, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Verse-end marker shape and tint.
class MarkerSettings extends ConsumerWidget {
  const MarkerSettings({super.key});

  static const _images = {
    MarkerStyle.rosette7: 'assets/ornaments/marker_7.png',
    MarkerStyle.rosette9: 'assets/ornaments/marker_9.png',
    MarkerStyle.rosette16: 'assets/ornaments/marker_16.png',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final art = watchThemeArt(context, ref);
    Widget choice({
      required bool selected,
      required String label,
      required Widget child,
      required VoidCallback onTap,
    }) {
      return Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? t.control : t.border,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final style in MarkerStyle.values)
                choice(
                  selected: settings.markerStyle == style,
                  label: switch (style) {
                    MarkerStyle.theme => l.markerTheme,
                    MarkerStyle.traditional => l.markerTraditional,
                    // Told apart by their points: 7, 9 or 16.
                    MarkerStyle.rosette7 => '${l.markerRosette} ٧',
                    MarkerStyle.rosette9 => '${l.markerRosette} ٩',
                    MarkerStyle.rosette16 => '${l.markerRosette} ١٦',
                  },
                  onTap: () => controller.setMarkerStyle(style),
                  child: style == MarkerStyle.theme
                      // The theme's own marker; Zakhrafa's is its rosette.
                      ? art == null
                            ? Image.asset(
                                _images[MarkerStyle.rosette16]!,
                                width: 40,
                                height: 40,
                              )
                            : SizedBox(
                                width: 40,
                                height: 40,
                                child: CustomPaint(
                                  painter: ArtPicturePainter(art.marker),
                                ),
                              )
                      : style == MarkerStyle.traditional
                      ? Text(
                          '۝',
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 30,
                            color: t.ink,
                          ),
                        )
                      : Image.asset(_images[style]!, width: 40, height: 40),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.markerThemeHint,
            style: TextStyle(color: t.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Text(l.markerTintLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              choice(
                selected: settings.markerTint == null,
                label: l.markerTintNone,
                onTap: () => controller.setMarkerTint(null),
                child: Icon(Icons.block, color: t.muted),
              ),
              for (final (i, c) in markerTints.indexed)
                choice(
                  selected: settings.markerTint == c,
                  label: '${l.markerTintLabel} ${i + 1}',
                  onTap: () => controller.setMarkerTint(c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
