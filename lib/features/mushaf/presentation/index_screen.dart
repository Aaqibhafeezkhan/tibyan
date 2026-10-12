import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/content_database.dart';
import '../../../core/router/keyboard_dismiss.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/interface_style.dart';
import '../../../core/theme/ornaments.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/surah_name.dart';
import '../../../l10n/app_localizations.dart';
import '../data/mushaf_repository.dart';
import '../mushaf_providers.dart';
import 'mushaf_screen.dart';
import 'navigation.dart';
import 'pages_map.dart';
import 'widgets/illuminated_frame.dart' show NumberFormatter;

/// Removes Arabic marks and unifies alef forms, for matching surah names.
String _fold(String s) => s
    .replaceAll(RegExp('[ً-ْٰـ]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .toLowerCase();

/// A "surah:ayah" reference such as 2:255, 2 255 or ٢:٢٥٥.
({int surah, int ayah})? parseVerseRef(String input) {
  final latin = input.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
  );
  final m = RegExp(r'^\s*(\d{1,3})\s*[:：.\s]\s*(\d{1,3})\s*$')
      .firstMatch(latin);
  if (m == null) return null;
  return (surah: int.parse(m[1]!), ayah: int.parse(m[2]!));
}

enum IndexTab { surahs, juz, hizb, pages, marks }

/// Row height in the index lists, fixed so the current row can be
/// scrolled into view before it is built.
double _rowExtent(BuildContext context) => context.look.elderly ? 96 : 76;

/// Height of a juz separator in the surah list.
double _dividerExtent(BuildContext context) =>
    context.look.isMakhtuta ? 44 : 40;

class IndexScreen extends ConsumerStatefulWidget {
  const IndexScreen({
    super.key,
    this.tab = IndexTab.surahs,
    this.surah,
    this.juz,
    this.hizb,
    this.page,
  });

  final IndexTab tab;

  /// The reader's current place, highlighted and scrolled to.
  final int? surah;
  final int? juz;
  final int? hizb;
  final int? page;

  @override
  ConsumerState<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends ConsumerState<IndexScreen> {
  String _query = '';

  Future<void> _goToRef(
    ({int surah, int ayah}) r,
    List<SurahRow> surahs,
  ) async {
    if (r.surah < 1 || r.surah > 114) return;
    // In a riwaya edition, a typed reference is in the riwaya's own count.
    final riwaya = await ref.read(riwayaDataProvider.future);
    if (!mounted) return;
    if (riwaya != null) {
      final ayah = r.ayah.clamp(1, riwaya.surahCounts[r.surah - 1]);
      await openPage(context, ref, riwaya.pageOf(r.surah, ayah));
      return;
    }
    final ayah = r.ayah.clamp(1, surahs[r.surah - 1].ayahCount);
    await openVerse(context, ref, surah: r.surah, ayah: ayah);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final surahs = ref.watch(surahsProvider).value;
    final riwaya = ref.watch(riwayaDataProvider).value;

    return DefaultTabController(
      length: IndexTab.values.length,
      initialIndex: widget.tab.index,
      child: LookScaffold(
        selected: RailItem.contents,
        body: SafeArea(
          child: Column(
            children: [
              LookTopBar(title: l.indexTitle),
              _IndexTabs(
                // The surahs' search field is left behind: its keyboard goes.
                onTap: (_) => dismissKeyboard(),
                labels: [
                  l.tabSurahs,
                  l.tabJuz,
                  l.tabHizb,
                  l.tabPages,
                  l.tabMarks,
                ],
              ),
              Expanded(
                child: surahs == null
                    ? Center(child: Text(l.loadingLabel))
                    : DismissKeyboardOnSwipe(
                        child: TabBarView(
                          children: [
                            _surahTab(context, surahs),
                            _StartsTab(
                              surahs: surahs,
                              // A riwaya edition: its own juz starts (KFGQPC).
                              starts: riwaya != null
                                  ? [
                                      for (final v in riwaya.juzStarts())
                                        riwaya.row(v),
                                    ]
                                  : ref
                                        .watch(juzStartsProvider)
                                        .value
                                        ?.map((j) => j.ayah)
                                        .toList(),
                              current: widget.juz,
                              title: (n) => l.juzLabel(n),
                            ),
                            // The riwayat's hizb divisions are not in their
                            // sources.
                            if (riwaya != null)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    riwaya.hasWordBoxes
                                        ? l.riwayaGaps
                                        : '${l.riwayaGaps}\n\n${l.riwayaNoWordBoxes}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              _StartsTab(
                                surahs: surahs,
                                starts: ref.watch(hizbStartsProvider).value,
                                current: widget.hizb,
                                title: (n) => l.hizbLabel(n),
                              ),
                            PagesMap(current: widget.page),
                            _MarksTab(surahs: surahs),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surahTab(BuildContext context, List<SurahRow> surahs) {
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final verseRef = parseVerseRef(_query);
    final pageNumber = int.tryParse(
      _query.trim().replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
      ),
    );
    final q = _fold(_query.trim());
    final shown = [
      for (final s in surahs)
        if (q.isEmpty ||
            _fold(s.nameAr).contains(q) ||
            _fold(s.nameEn).contains(q) ||
            '${s.id}' == q)
          s,
    ];
    final extras = <Widget>[
      if (verseRef != null && verseRef.surah >= 1 && verseRef.surah <= 114)
        ListTile(
          // Mirrors itself: points forward in either direction.
          leading: const Icon(Icons.arrow_forward),
          title: Text(
            '${l.surahWord(surahName(context, surahs[verseRef.surah - 1]))} ${verseRef.ayah}',
          ),
          onTap: () => _goToRef(verseRef, surahs),
        ),
      if (pageNumber != null &&
          pageNumber >= 1 &&
          pageNumber <= ref.watch(editionProvider).pageCount)
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l.pageOf('$pageNumber')),
          onTap: () => openPage(context, ref, pageNumber),
        ),
    ];
    // Juz separators: the juz each surah begins in, from the edition's
    // own juz starts; none while a search narrows the list.
    final riwaya = ref.watch(riwayaDataProvider).value;
    final starts = riwaya != null
        ? [for (final v in riwaya.juzStarts()) riwaya.row(v)]
        : ref.watch(juzStartsProvider).value?.map((j) => j.ayah).toList();
    int juzOf(SurahRow s) {
      var j = 1;
      for (final (i, a) in (starts ?? const <AyahRow>[]).indexed) {
        if (a.surah < s.id || (a.surah == s.id && a.number <= 1)) j = i + 1;
      }
      return j;
    }

    final entries = <_Entry>[];
    var last = 0;
    for (final s in shown) {
      if (q.isEmpty && starts != null) {
        final j = juzOf(s);
        if (j != last) entries.add((surah: null, juz: j));
        last = j;
      }
      entries.add((surah: s, juz: null));
    }
    final current = q.isEmpty ? widget.surah : null;
    final look = context.look;
    Widget list = _CurrentList(
      count: entries.length,
      extentOf: (i) => entries[i].surah == null
          ? _dividerExtent(context)
          : _rowExtent(context),
      currentIndex: current == null
          ? null
          : entries.indexWhere((e) => e.surah?.id == current),
      itemBuilder: (context, i, isCurrent) {
        final e = entries[i];
        final s = e.surah;
        if (s == null) return _JuzDivider(label: l.juzLabel(digits(e.juz!)));
        return _SurahRowTile(
          surah: s,
          current: isCurrent,
          ayahs: l.ayahCount(
            digits(
              ref.watch(surahAyahCountProvider(s.id)).value ?? s.ayahCount,
            ),
          ),
          // The edition's own count and page (a riwaya differs).
          page: digits(
            ref.watch(surahStartPageProvider(s.id)).value ??
                s.startPageIn(ref.watch(editionProvider)),
          ),
          onTap: () => openVerse(context, ref, surah: s.id, ayah: 1),
        );
      },
    );
    if (look.isMakhtuta) {
      // Paper rows inside a dark illuminated frame.
      list = Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: look.frame,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: look.gold, width: 1.2),
          ),
          child: ClipRect(child: list),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l.indexSearchHint,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (_) {
                  if (verseRef != null) _goToRef(verseRef, surahs);
                },
              ),
            ),
            ...extras,
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}

typedef _Entry = ({SurahRow? surah, int? juz});

/// The index's tabs, dressed per interface style: framed cells in
/// «مخطوطة», an underline in «هندسي», a pill in «ليلي ذهبي».
class _IndexTabs extends StatelessWidget {
  const _IndexTabs({required this.labels, required this.onTap});

  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final Decoration indicator = switch (l.style) {
      InterfaceStyle.makhtuta => BoxDecoration(
        color: l.frame,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: l.gold),
      ),
      InterfaceStyle.handasi => UnderlineTabIndicator(
        borderSide: BorderSide(color: l.control, width: 3),
        borderRadius: BorderRadius.circular(2),
      ),
      InterfaceStyle.layli => BoxDecoration(
        color: l.night ? l.gold : l.frame,
        borderRadius: BorderRadius.circular(24),
      ),
    };
    final selected = switch (l.style) {
      InterfaceStyle.makhtuta => l.onFrame,
      InterfaceStyle.handasi => l.control,
      InterfaceStyle.layli => l.night ? l.bg : l.onFrame,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: l.isHandasi ? null : const EdgeInsets.all(4),
        decoration: switch (l.style) {
          InterfaceStyle.makhtuta => BoxDecoration(
            color: l.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: l.line),
          ),
          InterfaceStyle.handasi => BoxDecoration(
            border: Border(bottom: BorderSide(color: l.line)),
          ),
          InterfaceStyle.layli => BoxDecoration(
            color: l.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: l.gold.withValues(alpha: .35)),
          ),
        },
        child: TabBar(
          onTap: onTap,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicator: indicator,
          indicatorSize: l.isHandasi
              ? TabBarIndicatorSize.label
              : TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: selected,
          unselectedLabelColor: l.sub,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
          tabs: [for (final t in labels) Tab(height: 44, text: t)],
        ),
      ),
    );
  }
}

/// A juz separator in the surah list: a tazhib band across a dark frame
/// in «مخطوطة»; a light label and hairline in the other styles.
class _JuzDivider extends StatelessWidget {
  const _JuzDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final Widget child = switch (l.style) {
      InterfaceStyle.makhtuta => ColoredBox(
        color: l.frame,
        child: Row(
          children: [
            const Expanded(child: TazhibBand(height: 10)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: l.gold),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: arabic ? 'ArefRuqaa' : null,
                  fontSize: 16,
                  color: l.onFrame,
                ),
              ),
            ),
            const Expanded(child: TazhibBand(height: 10)),
          ],
        ),
      ),
      InterfaceStyle.handasi => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 12,
              child: CustomPaint(painter: StarPainter(l.accent2, l.accent2)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: l.accent2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: l.line)),
          ],
        ),
      ),
      InterfaceStyle.layli => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Container(height: 1, color: l.gold.withValues(alpha: .4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: l.goldText,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 1, color: l.gold.withValues(alpha: .4)),
            ),
          ],
        ),
      ),
    };
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: child,
    );
  }
}

/// A list with known row heights that opens scrolled to the current row.
class _CurrentList extends StatefulWidget {
  const _CurrentList({
    required this.count,
    required this.currentIndex,
    required this.itemBuilder,
    this.extentOf,
  });

  final int count;
  final int? currentIndex;
  final double Function(int index)? extentOf;
  final Widget Function(BuildContext context, int index, bool current)
  itemBuilder;

  @override
  State<_CurrentList> createState() => _CurrentListState();
}

class _CurrentListState extends State<_CurrentList> {
  ScrollController? _scroll;

  double _extent(int i) => widget.extentOf?.call(i) ?? _rowExtent(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scroll != null) return;
    final c = widget.currentIndex;
    var offset = 0.0;
    // Leave two rows above the current one visible.
    if (c != null && c > 2) {
      for (var i = 0; i < c - 2; i++) {
        offset += _extent(i);
      }
    }
    _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      itemExtentBuilder: (i, _) => i < widget.count ? _extent(i) : null,
      itemCount: widget.count,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, i) =>
          widget.itemBuilder(context, i, i == widget.currentIndex),
    );
  }
}

/// A surah in the index: its number in a star, its title in the KFGQPC
/// calligraphy, the verse count, Meccan or Medinan, and its page.
class _SurahRowTile extends StatelessWidget {
  const _SurahRowTile({
    required this.surah,
    required this.current,
    required this.ayahs,
    required this.page,
    required this.onTap,
  });

  final SurahRow surah;
  final bool current;
  final String ayahs;
  final String page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    final s = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final english = Localizations.localeOf(context).languageCode != 'ar';
    final meccan = surah.revelation == 'meccan';
    final kind = meccan ? s.meccan : s.medinan;
    final nameSize = l.elderly ? 28.0 : 23.0;
    final Widget name = english
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                surah.nameEn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: l.ink,
                ),
              ),
              Text(
                '$ayahs · $kind',
                style: TextStyle(fontSize: 12, color: l.sub),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SurahNameText(
                surah: surah.id,
                name: surah.nameAr,
                size: nameSize,
                color: l.ink,
                height: l.isMakhtuta ? 1.8 : 1.6,
              ),
              if (!l.isMakhtuta)
                Text(
                  '$ayahs · $kind',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: l.elderly ? 15 : 12,
                    color: l.sub,
                    height: 1.1,
                  ),
                ),
            ],
          );
    final number = digits(surah.id);
    final Widget row = switch (l.style) {
      InterfaceStyle.makhtuta => Container(
        margin: const EdgeInsets.only(bottom: 2),
        color: current
            ? Color.alphaBlend(l.gold.withValues(alpha: .18), l.row)
            : l.row,
        child: Row(
          children: [
            const SizedBox(width: 10),
            StarBadge(
              text: number,
              fill: l.night ? l.surface : const Color(0xFFF1E1C2),
              line: l.gold,
              textColor: l.accent,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(child: name),
            if (!english)
              Text(
                ayahs,
                style: TextStyle(fontSize: l.elderly ? 16 : 13, color: l.sub),
              ),
            const SizedBox(width: 10),
            RevelationMark(meccan: meccan),
            const SizedBox(width: 10),
            Container(
              width: 54,
              color: l.frame,
              alignment: Alignment.center,
              child: Text(
                page,
                style: TextStyle(
                  fontSize: l.elderly ? 20 : 17,
                  fontWeight: FontWeight.w600,
                  color: l.onFrame,
                ),
              ),
            ),
          ],
        ),
      ),
      InterfaceStyle.handasi => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: current
              ? Color.alphaBlend(l.control.withValues(alpha: .10), l.row)
              : l.row,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: current ? l.control : l.line,
            width: current ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            StarBadge(
              text: number,
              fill: l.accent.withValues(alpha: .10),
              line: l.accent.withValues(alpha: .5),
              textColor: l.accent,
            ),
            const SizedBox(width: 12),
            Expanded(child: name),
            RevelationMark(meccan: meccan, size: 28),
            const SizedBox(width: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 48),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: l.accent2.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                page,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: l.accent2,
                ),
              ),
            ),
          ],
        ),
      ),
      InterfaceStyle.layli => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: current ? l.gold.withValues(alpha: .12) : null,
          border: Border(
            bottom: BorderSide(color: l.gold.withValues(alpha: .18)),
          ),
        ),
        child: Row(
          children: [
            StarBadge(
              text: number,
              fill: Colors.transparent,
              line: l.gold,
              textColor: l.goldText,
            ),
            const SizedBox(width: 12),
            Expanded(child: name),
            RevelationMark(meccan: meccan, size: 28),
            const SizedBox(width: 14),
            SizedBox(
              width: 44,
              height: 56,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipPath(
                      clipper: const ArchClipper(spring: .5),
                      child: ColoredBox(color: l.night ? l.surface : l.frame),
                    ),
                  ),
                  Positioned.fill(
                    top: 18,
                    child: Center(
                      child: Text(
                        page,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: l.night ? l.goldText : l.onFrame,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    };
    return Semantics(
      button: true,
      selected: current,
      label:
          '${s.surahWord(english ? surah.nameEn : surah.nameAr)}، $number، $ayahs، $kind، ${s.pageShort(page)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// A row of the juz and hizb lists.
class _Row extends StatelessWidget {
  const _Row({
    required this.current,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final bool current;
  final String badge;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.look;
    return Semantics(
      selected: current,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: current
              ? Color.alphaBlend(l.control.withValues(alpha: .10), l.row)
              : l.row,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(l.isMakhtuta ? 4 : 14),
            side: BorderSide(
              color: current ? l.control : l.line,
              width: current ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  StarBadge(
                    text: badge,
                    fill: l.isHandasi
                        ? l.accent
                        : l.gold.withValues(alpha: .15),
                    line: l.isHandasi ? l.accent : l.gold,
                    textColor: l.isHandasi ? l.surface : l.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: current
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: l.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: l.sub),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: l.isHandasi ? l.accent2 : l.goldText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Juz or hizb starts.
class _StartsTab extends ConsumerWidget {
  const _StartsTab({
    required this.surahs,
    required this.starts,
    required this.current,
    required this.title,
  });

  final List<SurahRow> surahs;
  final List<AyahRow>? starts;
  final int? current;
  final String Function(String n) title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final list = starts;
    if (list == null) return Center(child: Text(l.loadingLabel));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: _CurrentList(
          count: list.length,
          currentIndex: current == null ? null : current! - 1,
          itemBuilder: (context, i, isCurrent) {
            final a = list[i];
            // Rows of a riwaya edition carry its own numbers and page.
            final page = a.pageIn(ref.watch(editionProvider));
            return _Row(
              current: isCurrent,
              badge: digits(i + 1),
              title: title(digits(i + 1)),
              subtitle: l.juzStartsAt(
                surahName(context, surahs[a.surah - 1]),
                digits(a.number),
              ),
              trailing: l.pageShort(digits(page)),
              onTap: () => openPage(context, ref, page),
            );
          },
        ),
      ),
    );
  }
}

/// The reader's marks: the four fixed marks and named fawasil, updated as
/// they are set from the page view.
class _MarksTab extends ConsumerWidget {
  const _MarksTab({required this.surahs});

  final List<SurahRow> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.look;
    final marks = ref.watch(bookmarkSetsProvider).value;
    if (marks == null) return Center(child: Text(l.loadingLabel));
    if (marks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.noMarks,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.sub, height: 1.7),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final m in marks)
          ListTile(
            leading: Icon(Icons.bookmark, color: Color(m.color), size: 30),
            title: Text(
              m.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l.fasilLastAt(
                surahName(context, surahs[m.surah - 1]),
                '${m.ayah}',
                // The page in the edition shown now, not the one it was
                // set in.
                '${ref.watch(versePageProvider((m.surah, m.ayah))).value ?? m.page}',
              ),
              style: TextStyle(color: t.sub),
            ),
            onTap: () => openVerse(context, ref, surah: m.surah, ayah: m.ayah),
          ),
      ],
    );
  }
}
