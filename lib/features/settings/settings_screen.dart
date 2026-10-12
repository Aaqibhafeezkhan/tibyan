import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup.dart';
import '../home/whats_new.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';
import '../audio/player_bar.dart';
import '../audio/recitation.dart';
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/widgets/download_all_button.dart';
import '../mushaf/presentation/widgets/edition_badge.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;

/// The app's version as built (pubspec.yaml), e.g. `0.4.0 (5)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final t = context.look;
    final muted = TextStyle(color: t.sub);
    Widget nav(
      IconData icon,
      String title,
      VoidCallback onTap, {
      String? subtitle,
    }) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(subtitle, style: muted),
      // Mirrors itself: points left in Arabic, right in English.
      trailing: Icon(Icons.chevron_right, color: t.sub),
      onTap: onTap,
    );

    return LookScaffold(
      selected: RailItem.settings,
      body: SafeArea(
        child: Column(
          children: [
            LookTopBar(title: l.settingsTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      LookGroup(
                        icon: Icons.palette_outlined,
                        title: l.settingsGroupAppearance,
                        children: [
                          const InterfaceStylePicker(),
                          nav(
                            Icons.auto_stories_outlined,
                            l.appearanceTitle,
                            () => context.go('/settings/appearance'),
                            subtitle: ref
                                .watch(themeRegistryProvider)
                                .byId(settings.styleId)
                                .localizedName(
                                  Localizations.localeOf(context).languageCode,
                                ),
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.elderly),
                            title: Text(l.elderlyMode),
                            subtitle: Text(l.elderlyModeHint, style: muted),
                            value: settings.elderlyMode,
                            onChanged: controller.setElderlyMode,
                          ),
                        ],
                      ),
                      LookGroup(
                        icon: Icons.translate,
                        title: l.languageLabel,
                        children: [
                          RadioGroup<LanguageSetting>(
                            groupValue: settings.language,
                            onChanged: (v) =>
                                v == null ? null : controller.setLanguage(v),
                            child: Column(
                              children: [
                                RadioListTile(
                                  value: LanguageSetting.system,
                                  title: Text(l.languageSystem),
                                ),
                                RadioListTile(
                                  value: LanguageSetting.ar,
                                  title: Text(l.languageArabic),
                                ),
                                RadioListTile(
                                  value: LanguageSetting.en,
                                  title: Text(l.languageEnglish),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      LookGroup(
                        icon: Icons.menu_book_outlined,
                        title: l.readingTitle,
                        children: [
                          RadioGroup<MushafEdition>(
                            groupValue: settings.edition,
                            onChanged: (v) async {
                              if (v == null) return;
                              await controller.setEdition(v);
                              // An edition not on the device yet goes
                              // straight to its download, which starts on
                              // its own.
                              if (!ref
                                      .read(installedEditionsProvider)
                                      .contains(v) &&
                                  context.mounted) {
                                context.push('/mushaf/download');
                              }
                            },
                            child: Column(
                              children: [
                                for (final (e, name) in [
                                  (MushafEdition.madina1441, l.editionNew),
                                  (MushafEdition.madina1405, l.editionOld),
                                  (MushafEdition.shamarly, l.editionShamarly),
                                ])
                                  RadioListTile(
                                    value: e,
                                    title: Text(name),
                                    subtitle: EditionBadge(edition: e),
                                  ),
                                // The KFGQPC Madina mushafs of the other
                                // riwayat.
                                ListTile(
                                  title: Text(
                                    l.riwayatTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(l.riwayaEditionDesc),
                                ),
                                for (final e in MushafEdition.values)
                                  if (e.isRiwaya)
                                    RadioListTile(
                                      value: e,
                                      title: Text(editionName(l, e)),
                                      subtitle: EditionBadge(edition: e),
                                    ),
                              ],
                            ),
                          ),
                          const DownloadAllButton(),
                          SwitchListTile(
                            title: Text(l.keepScreenOn),
                            value: settings.keepScreenOn,
                            onChanged: controller.setKeepScreenOn,
                          ),
                          SwitchListTile(
                            title: Text(l.highlightDivineNames),
                            subtitle: Text(
                              l.highlightDivineNamesHint,
                              style: muted,
                            ),
                            value: settings.highlightDivineNames,
                            onChanged: controller.setHighlightDivineNames,
                          ),
                          SwitchListTile(
                            title: Text(l.twoPageSpread),
                            subtitle: Text(l.twoPageSpreadHint, style: muted),
                            value: settings.twoPageSpread,
                            onChanged: controller.setTwoPageSpread,
                          ),
                        ],
                      ),
                      LookGroup(
                        icon: Icons.fullscreen,
                        title: l.focusModeTitle,
                        children: const [_FocusModeCard()],
                      ),
                      LookGroup(
                        icon: Icons.headphones_outlined,
                        title: l.settingsGroupListening,
                        children: [
                          nav(
                            Icons.headphones_outlined,
                            l.playerSettings,
                            () => context.go('/settings/player'),
                            subtitle: switch (ref
                                .watch(currentReciterProvider)
                                .value) {
                              final r? => reciterLabel(context, r),
                              null => null,
                            },
                          ),
                          nav(
                            Icons.graphic_eq,
                            l.tasmeeTitle,
                            () => context.go('/settings/tasmee'),
                            subtitle: l.tasmeeSettingsNote,
                          ),
                          // Here as well as in the player's settings: it
                          // also works with touch reading and «آية آية»,
                          // with no recitation playing.
                          const _SajdahTimerCard(),
                        ],
                      ),
                      LookGroup(
                        icon: Icons.smart_display_outlined,
                        title: l.playerStyleLabel,
                        children: const [_PlayerStyleCard()],
                      ),
                      LookGroup(
                        icon: Icons.inventory_2_outlined,
                        title: l.settingsGroupData,
                        children: [
                          nav(
                            Icons.storage_outlined,
                            l.storageOpen,
                            () => context.push('/settings/storage'),
                            subtitle: l.storageOpenHint,
                          ),
                          ListTile(
                            leading: const Icon(Icons.ios_share),
                            title: Text(l.backupExport),
                            subtitle: Text(l.backupExportHint, style: muted),
                            onTap: () => _export(context, ref),
                          ),
                          ListTile(
                            leading: const Icon(Icons.restore),
                            title: Text(l.backupImport),
                            subtitle: Text(l.backupImportHint, style: muted),
                            onTap: () => _import(context, ref),
                          ),
                          SwitchListTile(
                            value: settings.crashReportsOptIn,
                            onChanged: controller.setCrashReportsOptIn,
                            title: Text(l.crashReportsLabel),
                            subtitle: Text(l.crashReportsHint, style: muted),
                          ),
                        ],
                      ),
                      LookGroup(
                        icon: Icons.info_outline,
                        title: l.aboutTitle,
                        children: [
                          nav(
                            Icons.new_releases_outlined,
                            l.whatsNewTitle,
                            () => showWhatsNew(context),
                          ),
                          nav(
                            Icons.info_outline,
                            l.aboutMushafTitle,
                            () => context.push('/mushaf/about'),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.aboutBody),
                                const SizedBox(height: 8),
                                Text(
                                  l.versionLabel(
                                    ref.watch(appVersionProvider).value ?? '',
                                  ),
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                      preview: UiLook.of(style, night: look.night),
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
              duration: const Duration(milliseconds: 180),
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

Future<void> _export(BuildContext context, WidgetRef ref) async {
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
    messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
  }
}

Future<void> _import(BuildContext context, WidgetRef ref) async {
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
    // The restored settings take effect now.
    if (r.settings > 0) ref.invalidate(settingsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l.backupDone(digits(r.added), digits(r.updated)))),
    );
  } on BackupException {
    messenger.showSnackBar(SnackBar(content: Text(l.backupInvalid)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
  }
}

/// «وضع التركيز»: the switch, how the tools are reached, and how the page
/// fills the screen.
class _FocusModeCard extends ConsumerWidget {
  const _FocusModeCard();

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
class _SajdahTimerCard extends ConsumerWidget {
  const _SajdahTimerCard();

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
class _PlayerStyleCard extends ConsumerWidget {
  const _PlayerStyleCard();

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
