import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import '../assistant/help_topics.dart';
import '../audio/player_bar.dart' show reciterLabel;
import '../audio/recitation.dart';
import '../home/whats_new.dart';
import '../khatma/domain/khatmah.dart' show CountingMode;
import '../khatma/khatma_providers.dart' show khatmaServiceProvider;
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/widgets/download_all_button.dart';
import '../mushaf/presentation/widgets/edition_badge.dart';
import '../mushaf/presentation/widgets/tajweed_legend.dart';
import 'report/report_screen.dart' show reportLocation;
import 'home_widgets_card.dart';
import 'settings_widgets.dart';

/// The eight tiles of the settings grid, each opening its own screen.
enum SettingsSection {
  appearance(Icons.palette_outlined),
  mushaf(Icons.auto_stories_outlined),
  listening(Icons.headphones_outlined),
  hifz(Icons.graphic_eq),
  khatma(Icons.event_repeat_outlined),
  storage(Icons.inventory_2_outlined),
  assistant(Icons.lightbulb_outline),
  about(Icons.info_outline);

  const SettingsSection(this.icon);

  final IconData icon;

  String get location => '/settings/section/$name';

  String title(AppLocalizations l) => switch (this) {
    appearance => l.settingsSectionAppearance,
    mushaf => l.settingsSectionMushaf,
    listening => l.settingsSectionListening,
    hifz => l.settingsSectionHifz,
    khatma => l.settingsSectionKhatma,
    storage => l.settingsSectionStorage,
    assistant => l.settingsSectionAssistant,
    about => l.settingsSectionAbout,
  };

  String hint(AppLocalizations l) => switch (this) {
    appearance => l.settingsSectionAppearanceHint,
    mushaf => l.settingsSectionMushafHint,
    listening => l.settingsSectionListeningHint,
    hifz => l.settingsSectionHifzHint,
    khatma => l.settingsSectionKhatmaHint,
    storage => l.settingsSectionStorageHint,
    assistant => l.settingsSectionAssistantHint,
    about => l.settingsSectionAboutHint,
  };

  List<SettingsGroup> get groups => settingsCatalog[this]!;
}

typedef SettingBuilder = Widget Function(BuildContext context, WidgetRef ref);

/// One setting: found by search under its title (in Arabic and English)
/// and its [keywords], and drawn by [build] in its section.
class SettingEntry {
  const SettingEntry(
    this.id,
    this.title,
    this.build, {
    this.keywords = '',
    this.link,
  });

  final String id;
  final String Function(AppLocalizations l) title;
  final SettingBuilder build;

  /// Other words a reader may search with, in both languages.
  final String keywords;

  /// When set, the entry is found by search only (it is not drawn in its
  /// section) and its search hit opens this location.
  final String? link;
}

Widget _none(BuildContext c, WidgetRef r) => const SizedBox.shrink();

/// A titled group of settings within a section.
class SettingsGroup {
  const SettingsGroup(this.icon, this.title, this.entries);

  final IconData icon;
  final String Function(AppLocalizations l) title;
  final List<SettingEntry> entries;
}

/// Every setting, once, in its section.
final Map<SettingsSection, List<SettingsGroup>> settingsCatalog = {
  SettingsSection.appearance: [
    SettingsGroup(Icons.palette_outlined, (l) => l.interfaceStyleTitle, [
      SettingEntry(
        'interfaceStyle',
        (l) => l.interfaceStyleTitle,
        (c, r) => const InterfaceStylePicker(),
        keywords: 'مخطوطة هندسي ليلي ذهبي ثيم style theme look',
      ),
      SettingEntry(
        'lightMode',
        (l) => l.modeLabel,
        (c, r) => const LightModePicker(),
        keywords:
            'إضاءة ليلي نهاري أبيض أسود داكن فاتح dark light night black white',
      ),
      SettingEntry(
        'elderlyMode',
        (l) => l.elderlyMode,
        (c, r) => _switch(
          c,
          r,
          icon: Icons.elderly,
          title: (l) => l.elderlyMode,
          hint: (l) => l.elderlyModeHint,
          value: (s) => s.elderlyMode,
          set: (ctrl, v) => ctrl.setElderlyMode(v),
        ),
        keywords: 'كبار السن خط كبير تكبير large text big font accessibility',
      ),
    ]),
    SettingsGroup(Icons.translate, (l) => l.languageLabel, [
      SettingEntry(
        'language',
        (l) => l.languageLabel,
        (c, r) => const LanguagePicker(),
        keywords: 'لغة عربي إنجليزي language arabic english',
      ),
    ]),
    SettingsGroup(Icons.text_fields, (l) => l.uiFontLabel, [
      SettingEntry(
        'uiFont',
        (l) => l.uiFontLabel,
        (c, r) => const UiFontPicker(),
        keywords: 'خط الواجهة font typeface changa plex',
      ),
    ]),
    SettingsGroup(Icons.widgets_outlined, (l) => l.widgetsTitle, [
      SettingEntry(
        'homeWidgets',
        (l) => l.widgetsTitle,
        (c, r) => const HomeWidgetsCard(),
        keywords: 'ودجت ودجات أداة أدوات الشاشة الرئيسية آية اليوم widget widgets home screen verse of the day',
      ),
    ]),
  ],
  SettingsSection.mushaf: [
    SettingsGroup(Icons.menu_book_outlined, (l) => l.editionLabel, [
      SettingEntry(
        'edition',
        (l) => l.onbEditionTitle,
        (c, r) => const _EditionPicker(),
        keywords: 'طبعة مصحف المدينة الشمرلي ورش قالون الدوري شعبة رواية edition riwaya warsh qalun shamarly',
      ),
      SettingEntry(
        'downloadAllEditions',
        (l) =>
            l.downloadAllEditions('').replaceAll(RegExp(r'\s*[(（].*[)）]'), ''),
        (c, r) => const DownloadAllButton(),
        keywords:
            'مركز التحميلات تحميل كل المصاحف download all downloads center',
      ),
    ]),
    SettingsGroup(Icons.auto_stories_outlined, (l) => l.appearanceTitle, [
      SettingEntry(
        'pageLook',
        (l) => l.appearanceTitle,
        (c, r) => const PageLookCard(),
        keywords: 'شكل الصفحة ثيم زخرفة تبيان page theme look ornament',
      ),
      SettingEntry(
        'markers',
        (l) => l.markerStyleLabel,
        (c, r) => const MarkerSettings(),
        keywords: 'فاصلة علامة نهاية الآية لون marker verse end tint',
      ),
      SettingEntry(
        'tajweed',
        (l) => l.tajweedColors,
        (c, r) => const TajweedSettings(),
        keywords: 'تجويد ألوان أحكام tajweed colours colors rules',
      ),
    ]),
    SettingsGroup(Icons.chrome_reader_mode_outlined, (l) => l.readingTitle, [
      SettingEntry(
        'keepScreenOn',
        (l) => l.keepScreenOn,
        (c, r) => _switch(
          c,
          r,
          title: (l) => l.keepScreenOn,
          value: (s) => s.keepScreenOn,
          set: (ctrl, v) => ctrl.setKeepScreenOn(v),
        ),
        keywords: 'الشاشة مضاءة قفل screen awake lock',
      ),
      SettingEntry(
        'highlightDivineNames',
        (l) => l.highlightDivineNames,
        (c, r) => _switch(
          c,
          r,
          title: (l) => l.highlightDivineNames,
          hint: (l) => l.highlightDivineNamesHint,
          value: (s) => s.highlightDivineNames,
          set: (ctrl, v) => ctrl.setHighlightDivineNames(v),
        ),
        keywords: 'لفظ الجلالة الله تلوين divine names allah',
      ),
      SettingEntry(
        'twoPageSpread',
        (l) => l.twoPageSpread,
        (c, r) => _switch(
          c,
          r,
          title: (l) => l.twoPageSpread,
          hint: (l) => l.twoPageSpreadHint,
          value: (s) => s.twoPageSpread,
          set: (ctrl, v) => ctrl.setTwoPageSpread(v),
        ),
        keywords: 'صفحتين متقابلتين جهاز لوحي two pages spread tablet',
      ),
      SettingEntry(
        'pageTurn',
        (l) => l.pageTurnLabel,
        (c, r) => const PageTurnCard(),
        keywords: 'تأثير قلب الصفحة تقليب ثلاثي الأبعاد تلاشي حركة انحناء الورقة ثني page turn flip curl bend paper 3d fade animation',
      ),
    ]),
    SettingsGroup(Icons.fullscreen, (l) => l.focusModeTitle, [
      SettingEntry(
        'focusMode',
        (l) => l.focusModeTitle,
        (c, r) => const FocusModeCard(),
        keywords: 'تركيز ملء الشاشة أدوات focus fullscreen tools page fill',
      ),
    ]),
  ],
  SettingsSection.listening: [
    SettingsGroup(Icons.headphones_outlined, (l) => l.settingsGroupListening, [
      SettingEntry(
        'player',
        (l) => l.playerSettings,
        (c, r) => SettingsNavTile(
          icon: Icons.record_voice_over_outlined,
          title: AppLocalizations.of(c).playerSettings,
          subtitle: switch (r.watch(currentReciterProvider).value) {
            final rec? => reciterLabel(c, rec),
            null => null,
          },
          onTap: () => c.push('/settings/player'),
        ),
        keywords:
            'القارئ الشيخ قراء سرعة تكرار reciter reciters speed repeat qari',
      ),
      SettingEntry(
        'audioDownloads',
        (l) => l.audioDownloads,
        (c, r) => SettingsNavTile(
          icon: Icons.download_outlined,
          title: AppLocalizations.of(c).audioDownloads,
          onTap: () => c.push('/mushaf/audio'),
        ),
        keywords: 'تحميل التلاوات بدون إنترنت download audio offline',
      ),
      SettingEntry(
        'sajdahTimer',
        (l) => l.sajdahTimer,
        (c, r) => const SajdahTimerCard(),
        keywords: 'سجدة سجود التلاوة مؤقت sajdah prostration timer',
      ),
    ]),
    SettingsGroup(Icons.smart_display_outlined, (l) => l.playerStyleLabel, [
      SettingEntry(
        'playerStyle',
        (l) => l.playerStyleLabel,
        (c, r) => const PlayerStyleCard(),
        keywords: 'شكل المشغل زر شريط player style pill button',
      ),
    ]),
  ],
  SettingsSection.hifz: [
    SettingsGroup(Icons.psychology_alt_outlined, (l) => l.hifzTitle, [
      SettingEntry(
        'hifz',
        (l) => l.hifzTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.psychology_alt_outlined,
          title: AppLocalizations.of(c).hifzTitle,
          onTap: () => c.push('/hifz'),
        ),
        keywords: 'حفظ مراجعة hifz memorize review',
      ),
      SettingEntry(
        'hifzGoals',
        (l) => l.settingsHifzGoals,
        (c, r) => SettingsNavTile(
          icon: Icons.flag_outlined,
          title: AppLocalizations.of(c).settingsHifzGoals,
          onTap: () => c.push('/hifz?tab=goals'),
        ),
        keywords: 'أهداف تذكير الحفظ goals reminders',
      ),
    ]),
    SettingsGroup(Icons.graphic_eq, (l) => l.tasmeeTitle, [
      SettingEntry(
        'tasmee',
        (l) => l.tasmeeTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.graphic_eq,
          title: AppLocalizations.of(c).tasmeeTitle,
          subtitle: AppLocalizations.of(c).tasmeeSettingsNote,
          onTap: () => c.push('/settings/tasmee'),
        ),
        keywords: 'تسميع تلاوة خطأ صرامة اهتزاز recitation check strictness',
      ),
      SettingEntry(
        'tasmeeModel',
        (l) => l.tasmeeModelTitle,
        _none,
        keywords: 'نموذج التعرف الصوت تنزيل model speech download',
        link: '/settings/tasmee',
      ),
      SettingEntry(
        'tasmeeTrain',
        (l) => l.tasmeeTrainTitle,
        _none,
        keywords: 'تدريب تسجيلات ساهم مساهمة تطوع منصة train training recordings contribute volunteer',
        link: '/settings/tasmee',
      ),
    ]),
  ],
  SettingsSection.khatma: [
    SettingsGroup(Icons.event_repeat_outlined, (l) => l.khatmaTitle, [
      SettingEntry(
        'khatmaPlans',
        (l) => l.settingsKhatmaPlans,
        (c, r) => SettingsNavTile(
          icon: Icons.event_repeat_outlined,
          title: AppLocalizations.of(c).settingsKhatmaPlans,
          onTap: () => c.push('/khatma'),
        ),
        keywords: 'ختمة خطة تذكير إشعار khatma plan reminder notification',
      ),
      SettingEntry(
        'wirdIndicator',
        (l) => l.settingsWirdIndicator,
        (c, r) => _switch(
          c,
          r,
          title: (l) => l.settingsWirdIndicator,
          value: (s) => s.showWirdIndicator,
          set: (ctrl, v) => ctrl.setShowWirdIndicator(v),
        ),
        keywords: 'ورد مؤشر wird portion indicator',
      ),
      SettingEntry(
        'khatmaCountingMode',
        (l) => l.khatmaCountingMode,
        (c, r) => const _KhatmaCountingModeTile(),
        keywords: 'احتساب طريقة ورد ختمة عد counting mode confirm',
      ),
      SettingEntry(
        'countListening',
        (l) => l.settingsCountListening,
        (c, r) => _switch(
          c,
          r,
          title: (l) => l.settingsCountListening,
          value: (s) => s.countListening,
          set: (ctrl, v) => ctrl.setCountListening(v),
        ),
        keywords: 'استماع احتساب ورد listening count',
      ),
      SettingEntry(
        'reports',
        (l) => l.reportsTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.insights_outlined,
          title: AppLocalizations.of(c).reportsTitle,
          onTap: () => c.push('/khatma/reports'),
        ),
        keywords: 'تقارير إحصاءات reports stats',
      ),
      SettingEntry(
        'journal',
        (l) => l.journalTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.edit_note,
          title: AppLocalizations.of(c).journalTitle,
          onTap: () => c.push('/khatma/journal'),
        ),
        keywords: 'تدبر ملاحظات journal notes',
      ),
    ]),
  ],
  SettingsSection.storage: [
    SettingsGroup(Icons.inventory_2_outlined, (l) => l.settingsGroupData, [
      SettingEntry(
        'storage',
        (l) => l.storageOpen,
        (c, r) => SettingsNavTile(
          icon: Icons.storage_outlined,
          title: AppLocalizations.of(c).storageOpen,
          subtitle: AppLocalizations.of(c).storageOpenHint,
          onTap: () => c.push('/settings/storage'),
        ),
        keywords: 'مساحة تخزين حذف storage space delete',
      ),
      SettingEntry(
        'downloads',
        (l) => l.downloadsOpen,
        (c, r) => SettingsNavTile(
          icon: Icons.download_for_offline_outlined,
          title: AppLocalizations.of(c).downloadsOpen,
          subtitle: AppLocalizations.of(c).downloadsOpenHint,
          // Only shows the downloads: it never starts one.
          onTap: () => c.push('/downloads'),
        ),
        keywords: 'التحميلات تحميل تنزيل إيقاف متابعة downloads download pause resume',
      ),
      SettingEntry(
        'backupExport',
        (l) => l.backupExport,
        (c, r) => ListTile(
          leading: const Icon(Icons.ios_share),
          title: Text(AppLocalizations.of(c).backupExport),
          subtitle: Text(
            AppLocalizations.of(c).backupExportHint,
            style: TextStyle(color: c.look.sub),
          ),
          onTap: () => exportBackup(c, r),
        ),
        keywords: 'نسخ احتياطي تصدير backup export',
      ),
      SettingEntry(
        'backupImport',
        (l) => l.backupImport,
        (c, r) => ListTile(
          leading: const Icon(Icons.restore),
          title: Text(AppLocalizations.of(c).backupImport),
          subtitle: Text(
            AppLocalizations.of(c).backupImportHint,
            style: TextStyle(color: c.look.sub),
          ),
          onTap: () => importBackup(c, r),
        ),
        keywords: 'استعادة استيراد restore import',
      ),
    ]),
  ],
  SettingsSection.assistant: [
    for (final g in HelpGroup.values)
      SettingsGroup(
        switch (g) {
          HelpGroup.usage => Icons.auto_stories_outlined,
          HelpGroup.marks => Icons.spellcheck,
          HelpGroup.faq => Icons.quiz_outlined,
        },
        switch (g) {
          HelpGroup.usage => (l) => l.helpGroupUsage,
          HelpGroup.marks => (l) => l.helpGroupMarks,
          HelpGroup.faq => (l) => l.helpGroupFaq,
        },
        [
          for (final t in helpTopics.where((t) => t.group == g))
            SettingEntry(
              'help.${t.id}',
              (l) => t.titleIn(l.localeName),
              (c, r) => SettingsNavTile(
                icon: t.icon,
                title: t.titleIn(AppLocalizations.of(c).localeName),
                onTap: () => c.push(t.route),
              ),
              keywords: '${t.keywords} مساعد مساعدة assistant help',
            ),
        ],
      ),
  ],
  SettingsSection.about: [
    SettingsGroup(Icons.info_outline, (l) => l.settingsSectionAbout, [
      SettingEntry(
        'whatsNew',
        (l) => l.whatsNewTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.new_releases_outlined,
          title: AppLocalizations.of(c).whatsNewTitle,
          onTap: () => showWhatsNew(c),
        ),
        keywords: 'الجديد تحديث whats new update changes',
      ),
      SettingEntry(
        'aboutMushaf',
        (l) => l.aboutMushafTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.menu_book_outlined,
          title: AppLocalizations.of(c).aboutMushafTitle,
          onTap: () => c.push('/mushaf/about'),
        ),
        keywords: 'المصادر الرخصة شكر sources licence license credits',
      ),
      SettingEntry(
        'version',
        (l) => l.aboutTitle,
        (c, r) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(c).aboutBody),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(c)
                    .versionLabel(r.watch(appVersionProvider).value ?? ''),
                style: TextStyle(color: c.look.sub),
              ),
            ],
          ),
        ),
        keywords: 'الإصدار عن التطبيق version about',
      ),
      SettingEntry(
        'reportProblem',
        (l) => l.reportProblemTitle,
        (c, r) => SettingsNavTile(
          icon: Icons.report_outlined,
          title: AppLocalizations.of(c).reportProblemTitle,
          subtitle: AppLocalizations.of(c).reportProblemHint,
          onTap: () => c.push(reportLocation),
        ),
        keywords: 'إبلاغ بلاغ مشكلة عطل اقتراح تواصل report problem bug feedback contact',
      ),
      SettingEntry(
        'crashReports',
        (l) => l.crashReportsLabel,
        _none,
        keywords: 'أعطال تقارير خصوصية crash reports privacy',
        link: reportLocation,
      ),
    ]),
  ],
};

/// Every setting with its section, in the grid's order.
Iterable<(SettingsSection, SettingEntry)> get allSettings sync* {
  for (final section in SettingsSection.values) {
    for (final g in section.groups) {
      for (final e in g.entries) {
        yield (section, e);
      }
    }
  }
}

final _marks = RegExp('[ً-ٰٟۖ-ۭـ]');

/// Folds what Arabic spelling varies on (marks, hamza seats, ta marbuta,
/// alif maqsura) and case, so a search finds a setting however it is typed.
String foldForSearch(String s) => s
    .toLowerCase()
    .replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي');

/// The settings matching [query]: every word in the Arabic or English
/// title or the keywords. Titles that start with the query come first.
List<(SettingsSection, SettingEntry)> searchSettings(String query) {
  final words = foldForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));
  final hits = <(int, SettingsSection, SettingEntry)>[];
  for (final (section, e) in allSettings) {
    final titles = foldForSearch('${e.title(ar)} ${e.title(en)}');
    final hay = '$titles ${foldForSearch(e.keywords)}';
    if (words.every(hay.contains)) {
      hits.add((titles.contains(words.first) ? 0 : 1, section, e));
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, s, e) in hits) (s, e)];
}

Widget _switch(
  BuildContext context,
  WidgetRef ref, {
  IconData? icon,
  required String Function(AppLocalizations l) title,
  String Function(AppLocalizations l)? hint,
  required bool Function(AppSettings s) value,
  required void Function(SettingsController c, bool v) set,
}) {
  final l = AppLocalizations.of(context);
  return SwitchListTile(
    secondary: icon == null ? null : Icon(icon),
    title: Text(title(l)),
    subtitle: hint == null
        ? null
        : Text(hint(l), style: TextStyle(color: context.look.sub)),
    value: ref.watch(settingsProvider.select(value)),
    onChanged: (v) => set(ref.read(settingsProvider.notifier), v),
  );
}

/// The edition, with the KFGQPC mushafs of the other riwayat; an edition
/// not on the device yet opens its download, which starts on its own.
class _EditionPicker extends ConsumerWidget {
  const _EditionPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final edition = ref.watch(settingsProvider.select((s) => s.edition));
    return RadioGroup<MushafEdition>(
      groupValue: edition,
      onChanged: (v) async {
        if (v == null) return;
        await ref.read(settingsProvider.notifier).setEdition(v);
        if (!ref.read(installedEditionsProvider).contains(v) &&
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
          ListTile(
            title: Text(
              l.riwayatTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}

class _KhatmaCountingModeTile extends ConsumerWidget {
  const _KhatmaCountingModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(
      settingsProvider.select((s) => s.khatmaCountingMode),
    );
    final label = switch (mode) {
      CountingMode.wirdConfirm => l.khatmaCountWirdConfirm,
      CountingMode.auto => l.khatmaCountAuto,
      CountingMode.ask => l.khatmaCountAsk,
      CountingMode.manual => l.khatmaCountManual,
    };
    return ListTile(
      title: Text(l.khatmaCountingMode),
      subtitle: Text(label, style: TextStyle(color: context.look.sub)),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _pickMode(context, ref, mode),
    );
  }

  void _pickMode(
    BuildContext context,
    WidgetRef ref,
    CountingMode current,
  ) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l.khatmaCountingMode,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            RadioGroup<CountingMode>(
              groupValue: current,
              onChanged: (v) async {
                if (v == null) return;
                Navigator.of(sheetContext).pop();
                await ref
                    .read(settingsProvider.notifier)
                    .setKhatmaCountingMode(v);
                final primary =
                    await ref.read(khatmaServiceProvider).status();
                if (primary != null) {
                  await ref.read(khatmaServiceProvider).updatePlan(
                    primary.khatmah.copyWith(counting: v),
                  );
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<CountingMode>(
                    value: CountingMode.wirdConfirm,
                    title: Text(l.khatmaCountWirdConfirm),
                    subtitle: Text(l.khatmaCountWirdConfirmSubtitle),
                  ),
                  RadioListTile<CountingMode>(
                    value: CountingMode.auto,
                    title: Text(l.khatmaCountAuto),
                  ),
                  RadioListTile<CountingMode>(
                    value: CountingMode.ask,
                    title: Text(l.khatmaCountAsk),
                  ),
                  RadioListTile<CountingMode>(
                    value: CountingMode.manual,
                    title: Text(l.khatmaCountManual),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
